# 08 — Hot reload in the engine layer

*How Nexus Engine detects, routes, and applies runtime changes to resources,
localization, and scene data — and where we draw the line on code hot reload.*

> **Release alignment:** Resource hot reload **v0.9.0**; localization reload
> **v1.2.0**; scene hot reload **v1.0.0+**; code hot reload **no earlier than v2.x**
> (if ever).

Nexus Engine is where hot reload becomes a **first-class concern**. Unlike
zGameLib (which provides rebuild primitives) or Crucible (which drives the UI for
reload), Nexus Engine owns the **event bus**, the **resource cache**, and the
**scene tree** — all of which must react when data changes on disk or the editor
sends a patch.

---

## Difficulty spectrum

```ascii
EASIER                                          HARDER
────────────────────────────────────────────────────────────────────
Localization    Resources      Scene files    Shaders       Game logic
  key swap     (tex/mesh)    (PackedScene)  (SPIR-V)      (Zig code)
    │              │              │             │              │
    ▼              ▼              ▼             ▼              ▼
  stateless    re-upload      re-instantiate  rebuild       entire runtime
  string swap  to GPU +       or diff patch   pipelines     must be replaced
               signal nodes                                 (Zig has no live
                                                            code swapping)
```

**Nexus strategy:** start at the left and add capability per release. Ship
localization and resource hot reload in v0.9.0–v1.2.0; scene hot reload after
PackedScene lands; shader hot reload as a power-user feature; code hot reload
not on the roadmap.

---

## Reload event bus

Every hot reload flows through a single typed event bus on `NexusContext`:

```zig
// nexus/core/reload_event_bus.zig — pseudocode
pub const ReloadEvent = union(enum) {
    resource: struct { uid: ResourceUid, path: []const u8, resource: *Resource },
    locale: struct { tag: LocaleTag },
    scene: struct { path: []const u8, scene: *PackedScene },
    shader: struct { path: []const u8, spirv: []const u8 },
    editor_command: struct { command: EditorReloadCommand },
};

pub const ReloadEventBus = struct {
    subscribers: std.MultiArrayList(Subscriber),

    pub fn publish(self: *ReloadEventBus, event: ReloadEvent) void {
        for (self.subscribers.items) |sub| sub.callback(event);
    }

    pub fn subscribe(self: *ReloadEventBus, callback: *const fn (ReloadEvent) void) SubscriptionId { ... }
    pub fn unsubscribe(self: *ReloadEventBus, id: SubscriptionId) void { ... }
};
```

This is **not** a generic signal system. It is a narrow bus with exactly the
event types the engine knows how to reload. SceneNodes, ECS systems, and servers
subscribe to the events they care about.

---

## Resource hot reload (v0.9.0)

The most impactful hot reload for iterative development: a texture, mesh, or
material changes on disk, and the engine propagates the update to every node and
draw call referencing it.

### File watcher → ResourceDB

```ascii
File watcher (OS / platform)
        │
        ▼  "file changed: res://textures/hero.png"
ResourceLoader.reimport(path)
        │
        ▼
ResourceDB.invalidate(path)
        │
        ▼
ReloadEventBus.publish(.resource{ .uid = …, .resource = new_res })
        │
        ├──► SceneNode subscribers: material_override → re-bind
        ├──► ECS DrawInstance components: update texture handle
        ├──► RenderingServer: re-upload to GPU, update descriptor sets
        └──► Crucible (if attached): refresh inspector thumbnail
```

### ResourceDB invalidation

```zig
// nexus/resource/resource_db.zig — pseudocode
pub const ResourceDB = struct {
    cache: std.AutoHashMap(ResourceUid, *Resource),
    deps: std.AutoHashMap(*Resource, []Dependency),

    pub fn invalidate(self: *ResourceDB, path: []const u8) !void {
        const uid = self.uid_for_path.get(path) orelze return;
        const old = self.cache.get(uid) orelze return;

        // Re-import and re-decode
        const bytes = try self.fs.readAll(path);
        const new = try self.importer_registry.reimport(uid, bytes, path);

        // Atomically swap in cache
        self.cache.put(uid, new);

        // Signal consumers
        self.bus.publish(.{ .resource = .{
            .uid = uid,
            .path = path,
            .resource = new,
        }});

        old.unref();  // let GC collect when no nodes hold it
    }
};
```

### What nodes do on `ResourceReloaded`

```zig
// Pseudocode — MeshInstance3D subscriber
fn onResourceReloaded(node: *MeshInstance3D, event: ReloadEvent) void {
    const reload = event.resource orelze return;
    if (node.mesh) |m| if (m.uid == reload.uid) {
        node.mesh = reload.resource.cast(MeshResource);
        ctx.rendering.updateMeshInstance(node.render_instance, node.mesh.?);
    };
}
```

### ECS path

Systems that store resource handles as components update them during a dedicated
reload-resolve pass:

```zig
fn reloadDrawInstances(world: *World, bus: *ReloadEventBus) void {
    var q = world.query(.{ DrawInstance });
    while (q.next()) |entity| {
        // Each DrawInstance stores texture/mesh UID; if it matches
        // the reloaded resource, update the GPU handle.
    }
}
```

---

## Localization hot reload (v1.2.0)

The simplest hot reload in the engine: JSON locale files are loaded as resources.
When a locale file changes on disk:

```ascii
.po edited → build.zig re-compiles → JSON updated
        │
        ▼
ResourceLoader.load("res://locale/de.json")
        │
        ▼
ReloadEventBus.publish(.locale{ .tag = "de" })
        │
        ▼
resolve_localized_strings ECS system
(all LocalizedText components updated)
```

No GPU work, no scene patching, no pipeline rebuild. The cost is a single ECS
query plus string copies. This is the hot reload you ship to players when you
patch locale files in a live game.

**Design detail:** the `LocalizationSystem.setLocale` function doubles as the
reload entry point — passing the same locale tag that is already active triggers
a re-resolve:

```zig
// Called by locale reload subscriber
fn onLocaleReloaded(ctx: *NexusContext, tag: []const u8) !void {
    try ctx.localization.setLocale(tag);  // re-loads JSON, re-resolves
}
```

---

## Scene hot reload (v1.0.0+)

Scene files (`.fscn`) are `PackedScene` resources. When a scene file changes,
the engine can either:

1. **Re-instantiate** — destroy the old subtree, spawn the new one from the
   updated `PackedScene`. Simple but loses runtime state (transform, script
   variables).
2. **Diff and patch** — walk the existing subtree, match nodes by `NodeId` or
   path, and apply property deltas. Preserves runtime state but requires a
   structural comparison.

**Nexus strategy:** start with re-instantiation (option 1 — safe, correct) and
add diff-patch as a performance optimization in a later release.

```ascii
.fscn file saved
        │
        ▼
ResourceDB.invalidate("res://scenes/level1.fscn")
        │
        ▼
SceneTree.findInstancesOf(uid)
        │
        ├── For each instance:
        │     • Save runtime state (transform, visibility, script vars)
        │     • Remove old subtree
        │     • Instantiate new PackedScene
        │     • Restore runtime state by NodeId match
        │
        ▼
ReloadEventBus.publish(.scene{ .path = …, .scene = new_scene })
```

---

## Shader hot reload (later, opt-in)

When a GLSL file changes:

1. `shaderc` (or embedded compiler) re-compiles to SPIR-V.
2. `RenderingServer` finds all pipelines using that shader.
3. New `VkShaderModule` + `VkPipeline` built; old ones freed after GPU idle.
4. Material resources that reference the shader update their pipeline handle.

This is **not** in the v1 roadmap because:
- Runtime shader compilation adds complexity (bundling shaderc or shipping SPIR-V).
- Pipeline cache invalidation is expensive (some drivers take 100+ ms).
- Most teams pre-compile shaders in CI.

When it ships, it will be opt-in via `-Dhot-shaders=true`.

---

## What about code hot reload in Zig?

**Zig has no stable code hot reload mechanism.** There is no equivalent of
Unreal's Live Coding (hot-patch DLLs) or C++'s shared-library swap. Key reasons:

| Approach | Zig viability |
|----------|---------------|
| Shared library `.so`/`.dll` hot swap | Possible but Rust-level painful — Zig has no stable ABI |
| Function pointer table swap | Manual, fragile, requires every system to be pointer-indirected |
| Comptime-generated dispatch | Works for data but not for control flow |
| VM / interpreter (scripts) | Not in scope (no GDScript, no Lua) |

**Nexus stance:** Rather than hack a brittle code-reload system into native Zig,
we invest in **data-driven hot reload** — resources, localization, scenes, and
shaders — which covers 95 % of the iteration loop. For the remaining 5 % (game
logic changes), the standard `zig build` + restart cycle is adequate until Zig
itself ships a runtime code-swapping feature.

> **Future possibility:** If the community produces a stable Zig shared-library
> reload pattern, Nexus Engine could adopt it as an optional `-Dhot-code` flag.
> But it will never be the default iteration path.

---

## Data-first event flow (complete picture)

```ascii
                    ┌──────────────────────────────┐
                    │  FILE SYSTEM / EDITOR         │
                    │  file change · editor command │
                    └──────────────┬───────────────┘
                                   │
                    ┌──────────────▼───────────────┐
                    │  NEXUS RELOAD EVENT BUS       │
                    │  (ReloadEventBus on Context)   │
                    └──────┬──────┬──────┬──────────┘
                           │      │      │
              ┌────────────┘      │      └────────────┐
              ▼                   ▼                   ▼
    ┌──────────────────┐  ┌──────────────┐  ┌──────────────────┐
    │ RESOURCE SYSTEM  │  │ LOCALIZATION │  │  SCENE TREE      │
    │ ResourceDB       │  │ system       │  │  nodes + ECS    │
    │ re-import ·      │  │ re-load      │  │  re-bind ·      │
    │ re-upload GPU    │  │ re-resolve   │  │  re-instantiate │
    └──────────────────┘  └──────────────┘  └──────────────────┘
                           │
                           ▼
              ┌──────────────────────┐
              │  RENDERING SERVER    │
              │  descriptor update · │
              │  pipeline rebuild    │
              └──────────────────────┘
```

---

## Comparison with other engines

| Engine | Resource reload | Scene reload | Code reload |
|--------|----------------|--------------|-------------|
| **Godot** | `ResourceReloader` — file watcher → signal on `Resource` | Re-import `.tscn`; runtime state preserved | GDScript hot-reloads natively; GDExtension limited |
| **Unity** | Addressables — `Addressables.LoadAsset` + `ResourceManager` | Re-load scene additive | C# domain reload (slow, improving with DOTS) |
| **Unreal** | Asset Registry → `FAssetData` in Editor | Level reload via `UWorld` | **Live Coding** — patch .dll at runtime |
| **Bevy** | `AssetServer` → `AssetEvent::Modified` | Despawn/spawn entities | `bevy_hot_reload` (crates.io, experimental) |
| **Nexus** | ResourceDB + typed `ReloadEventBus` | Re-instantiate (v1), diff patch (later) | **Not in scope** — data-first, restart-for-code |

---

## Summary

| Area | Mechanism | Ships |
|------|-----------|-------|
| Resource (tex/mesh) | File watcher → ResourceDB → EventBus → GPU re-upload | v0.9.0 |
| Localization | File watcher → JSON re-load → ECS re-resolve | v1.2.0 |
| Scene `.fscn` | Re-instantiate with state restore | v1.0.0+ |
| Shader GLSL → SPIR-V | Pipeline rebuild (opt-in `-Dhot-shaders`) | Post-1.0 |
| Code (Zig) | **Not supported** — restart for code changes | N/A |

**Rule of thumb:** If the change fits in a data file, hot reload it. If it
requires a recompile, restart. This covers the 95 % case without compromising
Zig's compilation model.

---

## Bibliography

- **Nexus Reference** — [`../Nexus_Reference.md`](../Nexus_Reference.md) §4.4 (ResourceDB)
- **Resources** — [05-resource-and-asset-management.md](05-resource-and-asset-management.md) (hot reload signals)
- **Localization** — [07-localization-system.md](07-localization-system.md) (re-resolve on locale change)
- **zGameLib hot reload** — `libs/zGameLib/docs/theory/08-hot-reload.md` (Tier 1 primitives)
- **Crucible hot reload** — [09-hot-reload-crucible.md](09-hot-reload-crucible.md) (editor integration)
- **Godot** — [`Resource` hot reload](https://docs.godotengine.org/en/stable/classes/class_resource.html#class-resource-signal-changed)
- **Unity Addressables** — [Addressables overview](https://docs.unity3d.com/Packages/com.unity.addressables@latest/manual/index.html)
- **Unreal Live Coding** — [Live Coding overview](https://docs.unrealengine.com/en-US/ProgrammingAndScripting/LiveCoding/)
- **Bevy Assets** — [`AssetEvent::Modified`](https://docs.rs/bevy/latest/bevy/asset/enum.AssetEvent.html)
