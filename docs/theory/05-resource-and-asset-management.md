# 05 — Resource and asset management

*How Nexus Engine loads, caches, and identifies assets — and what stays in zGameLib as
raw decode I/O.*

> **Release alignment:** minimal `ResourceDB` **v0.2.0** (`textured-quad`); hot-reload **v0.9.0**.

Redot's `core/io/resource_loader.cpp` and `Resource` hierarchy are **engine**
concerns: paths, UIDs, import metadata, reference counting, and dependency graphs.
zGameLib's planned `zassets` module is **decode-only**: bytes on disk → structs in
memory. This chapter draws the line.

---

## Two layers, one pipeline

```ascii
  Disk file                    Tier 1 (zGameLib)              Tier 2 (Nexus Engine)
  ─────────                    ─────────────────              ────────────────
  hero.gltf  ──read bytes──►   zassets.parseGltf()  ──►       MeshResource
  tex.png    ──read bytes──►   zassets.decodeImage() ──►      TextureResource
                               (no UID, no cache)             ResourceDB.cache
                                                              RenderingServer upload
```

**Nexus Engine never re-implements PNG parsing** if zGameLib provides it.  
**zGameLib never tracks** `res://` paths or `.import` sidecars.

---

## Resource types (Nexus Engine)

| Type | Wraps | GPU upload? |
|------|-------|-------------|
| `TextureResource` | CPU image + format metadata | Yes, via RenderingServer |
| `MeshResource` | Vertices, indices, skin weights | Yes |
| `MaterialResource` | Shader + params | Yes |
| `PackedScene` | Node subtree on disk | No (instantiates nodes) |
| `AudioStream` | PCM or compressed buffer | Via AudioServer |
| `ScriptResource` | Zig source / bytecode (later) | No |

Each extends a common header:

```zig
const Resource = struct {
    uid: ResourceUid,           // stable id (see below)
    path: ?[]const u8,          // res:// path if file-backed
    refcount: std.atomic.u32,
    load_state: LoadState,

    fn ref(self: *Resource) void,
    fn unref(self: *Resource) void,
};
```

---

## Path resolution: `res://` and packs

Nexus Engine defines **virtual paths** (Redot-compatible ergonomics, new implementation):

```zig
const FileSystem = struct {
    mounts: []Mount,  // ordered: project dir, pack, optional DLC

    pub fn open(self: *FileSystem, path: []const u8) Error!File {
        // res://textures/a.png → mount lookup
    },
};
```

| Mount | Source | Tier |
|-------|--------|------|
| Project directory | Real filesystem | Nexus VFS |
| `.fpck` archive | zstd-compressed pack | Nexus reader; zstd from Tier 1 |
| Memory | `FileAccessMemory` for tests | Nexus Engine |

**Tier 1 `zgame.archive` (planned):** read-only byte slice from archive entry.  
**Nexus Engine:** mount order, path normalization, security policy (no `..` escape).

---

## UID system

Redot 4+ uses resource UIDs for stable references when files move. Nexus Engine adopts
the same **idea**:

```zig
const ResourceUid = struct {
    id: u64,

    // Serialized as: uid://abc123xyz in .fscn files
};
```

| Concern | Owner |
|---------|-------|
| Generate UID on first import | Nexus import pipeline (runtime registration; UI in Link-editor) |
| Resolve UID → path | `ResourceDB` |
| Store UID in scene files | `PackedScene` serializer |

zGameLib has **no opinion** on UIDs.

---

## ResourceLoader flow

```zig
const ResourceLoader = struct {
    db: *ResourceDB,
    fs: *FileSystem,
    importers: ImporterRegistry,

    pub fn load(self: *ResourceLoader, path: []const u8, comptime T: type) Error!*T {
        if (self.db.get(path)) |existing| return existing.cast(T);

        const bytes = try self.fs.readAll(path);
        const ext = extension(path);

        if (self.importers.find(ext)) |imp| {
            const res = try imp.import(bytes, path);
            try self.db.insert(path, res);
            return res.cast(T);
        }

        return error.NoImporter;
    }
};
```

### Import vs load

| Stage | Where | What happens |
|-------|-------|--------------|
| **Import** (editor) | Link-editor triggers Nexus importer | `.gltf` → optimized `MeshResource` blob + sidecar metadata |
| **Load** (runtime) | `ResourceLoader` | Read blob → typed resource → cache |

Runtime games can ship **pre-imported** blobs only; Link-editor is optional.

---

## Dependency tracking

When `MeshResource` references `MaterialResource` and textures:

```zig
const ResourceDB = struct {
    cache: HashMap(PathOrUid, *Resource),
    deps: HashMap(*Resource, []PathOrUid),

    pub fn loadRecursive(self: *ResourceDB, root: *Resource) Error!void {
        for (root.dependencies()) |dep| {
            _ = try self.loader.load(dep.path, dep.type);
        }
    }
};
```

Hot-reload (editor): when file watcher fires, `ResourceDB.invalidate(path)` and
signals `ResourceReloaded` to SceneNodes (Tier 2 signals).

---

## Relationship to scene nodes

Nodes hold **handles**, not duplicate asset data:

```zig
const MeshInstance3D = struct {
    base: SceneNode,
    mesh: ?*MeshResource,      // refcounted
    material_override: ?*MaterialResource,
};
```

On `enterTree`:

1. Ensure resources loaded (`loadRecursive`)
2. Register with `RenderingServer` (instance id)
3. Optionally `EcsBridge.attach` → `DrawInstance` component with same handles

---

## zGameLib: what Tier 1 will provide

From upstream reference (planned siblings):

| zGameLib module | Returns | Does not return |
|-----------------|---------|-----------------|
| `zassets.parseGltf` | Mesh buffers, materials (CPU) | `MeshResource` |
| `zassets.decodeImage` | pixels, w/h, format | `TextureResource` |
| `zgame.zclip` | Animation clips | `AnimationPlayer` node |
| `zgame.compress` | zstd frames | Pack mount policy |

Nexus Engine wraps these in **resource constructors**:

```zig
pub fn meshFromGltf(bytes: []const u8, alloc: Allocator) !*MeshResource {
    const parsed = try zgame.assets.parseGltf(bytes);
    defer parsed.deinit();
    return MeshResource.fromParsed(alloc, parsed);
}
```

---

## Serialization formats (Nexus-owned)

| Format | Contents |
|--------|----------|
| `.fscn` | Scene node tree + external resource refs (path or UID) |
| `.fres` | Single resource blob (binary or structured) |
| `.fpck` | Export pack (many files) |
| `.fimport` | Sidecar metadata (importer version, options) — Link-editor writes |

Not in zGameLib — these encode **engine** semantics.

---

## Garbage collection

Reference counting + epoch collection (Redot-style `RefCounted`):

```zig
fn collectGarbage(db: *ResourceDB) void {
    // After scene change: unref unreachable; free at 0
}
```

Weak refs for caches (RenderingServer texture cache) avoid cycles.

---

## Link-editor's role

| Action | Layer |
|--------|-------|
| Import dialog, preset UI | Link-editor |
| Importer implementation | Nexus plugin |
| Reimport on save | Link-editor calls `EditorHost.reimport(path)` |
| Thumbnail generation | Nexus Engine via RenderingServer offscreen |

---

## Clean-room slimming vs Redot

| Redot module | Nexus decision |
|--------------|----------------|
| Full import stack in editor | Link-editor UI + Nexus importers |
| `ResourceFormatLoader` C++ | Zig vtables in Nexus Engine |
| Assimp | glTF + uFBX via zGameLib |
| In-engine translation | `.po` → `build.zig` → JSON; `LocalizationSystem` — [07](07-localization-system.md) (v1.2.0) |

---

## Summary

| Question | Answer |
|----------|--------|
| Who parses files? | zGameLib (decode) |
| Who owns cache and UID? | Nexus Engine `ResourceDB` |
| Who uploads GPU? | Nexus Engine `RenderingServer` using zGameLib GPU helpers |
| What do nodes store? | Refcounted resource pointers |
| What does Link-editor touch? | Paths, import presets, reimport — via EditorHost |

---

## Bibliography

- Redot `core/io/resource_loader.h` — behavioral reference (study only)
- zGameLib Reference §4 — Asset loading (upstream)
- Nexus Engine Reference — [`../Nexus_Reference.md`](../Nexus_Reference.md) §4.4, §8

---

**End of theory ladder.** Return to [`README.md`](README.md) or the
[`Nexus_Reference.md`](../Nexus_Reference.md) for the component map.