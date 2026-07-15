# 09 — Hot reload in the editor

*How Crucible drives and consumes hot reload across the three tiers — file
watching, reimport, play-in-editor, and live asset iteration.*

> **Release alignment:** Editor-driven resource hot reload **v1.1.0+**; play-in-editor
> **v1.0.0** (editor-free runtime); full Crucible with docks and hot reload UI
> **v1.1.0+** (editor repo spins out).

Crucible (Tier 3) is both a **consumer** and a **driver** of hot reload:

- **Consumer:** When the user edits a file in an external tool (Blender, Aseprite,
  VS Code), Crucible detects the change and routes it to Nexus Engine's
  `ReloadEventBus`.
- **Driver:** When the user clicks "Reimport" or edits a property in the inspector,
  Crucible programmatically triggers a reload.

This two-way relationship is the key design constraint. The `EditorHost` API
(matured in v1.0.0) must expose enough surface for Crucible to trigger every
reload type that Nexus Engine supports — without Crucible knowing the internals
of what "reload" means at each level.

---

## Editor as file watcher

Crucible runs a **file watcher** thread (or uses the OS notification API:
`inotify` on Linux, `FSEvents` on macOS, `ReadDirectoryChangesW` on Windows).
When a file under the project root changes:

```ascii
OS file notification
        │
        ▼
Crucible file watcher thread
        │
        ├── Is this a resource file? (.png, .gltf, .wav, .fres, …)
        │    └─► EditorHost.reimport(path)
        │
        ├── Is this a scene file? (.fscn)
        │    └─► EditorHost.reloadScene(path)
        │
        ├── Is this a locale file? (.po, .json)
        │    └─► EditorHost.reloadLocale(tag)
        │
        └── Is this a shader file? (.glsl, .vert, .frag)
             └─► EditorHost.reloadShader(path)
```

The `EditorHost` methods are thin wrappers that call into Nexus Engine's
`ResourceDB` and `ReloadEventBus`:

```zig
// In Nexus Engine — EditorHost implementation
pub const EditorHost = struct {
    ctx: *NexusContext,

    pub fn reimport(self: *EditorHost, path: []const u8) !void {
        try self.ctx.resource_db.invalidate(path);
    }

    pub fn reloadScene(self: *EditorHost, path: []const u8) !void {
        const new_scene = try self.ctx.resource_loader.load(path, PackedScene);
        self.ctx.bus.publish(.{ .scene = .{ .path = path, .scene = new_scene } });
    }

    pub fn reloadLocale(self: *EditorHost, tag: []const u8) !void {
        try self.ctx.localization.setLocale(tag);
    }

    pub fn reloadShader(self: *EditorHost, path: []const u8) !void {
        // Opt-in: only works if engine is built with -Dhot-shaders
        if (!self.ctx.config.hot_shaders) return error.HotShadersDisabled;
        try self.ctx.rendering.reloadShader(path);
    }
};
```

---

## Play-in-editor as hot reload

The most visible hot reload for game developers is **play-in-editor**: hitting
play while the editor is open, the game starts in the same process (or a child
process), and changes made while playing can be applied or discarded.

```ascii
EDITOR MODE                        PLAY MODE
────────────                       ──────────
SceneTree (editable)               SceneTree (copy / forked)
  Player                              Player
    Sprite                              Sprite (runtime state)
Inspector writes props             Read-only (unless "edit while playing")
ECS bridge: read + write for       ECS systems running
  debug display
ResourceDB shared                   ResourceDB shared (reads propagate)
                                    Hot reload events still flow in
```

**Crucible's approach:**

1. **Same-process** — the game runs inside the editor's process, on a separate
   tick schedule. This avoids IPC complexity and keeps ResourceDB shared.
2. **SceneTree fork** — before entering play mode, Crucible clones the active
   scene via `PackedScene`. The play session mutates the clone; exiting play
   mode discards it (or applies selected changes back).
3. **ResourceDB is shared** — both editor and play mode see the same loaded
   resources. When a file changes, both react.
4. **"Edit while playing"** — optional: Crucible can write property changes
   through `EditorHost` even during play mode, which Nexus Engine routes through
   the same `ReloadEventBus`.

### Play-in-editor pseudocode

```zig
// Psuedocode — Crucible play mode manager
const PlaySession = struct {
    editor_host: *EditorHost,
    backup_scene: ?*PackedScene,
    play_context: *NexusContext,

    pub fn enter(self: *PlaySession) !void {
        // Snapshot current scene
        self.backup_scene = try self.editor_host.serializeActiveScene();

        // Create a fresh context for play mode
        self.play_context = try self.editor_host.forkContext();

        // Start ticking the play context
        self.editor_host.setPlayMode(.active);
    }

    pub fn exit(self: *PlaySession, apply: bool) !void {
        self.editor_host.setPlayMode(.inactive);

        if (apply) {
            // Write modified properties back to editor scene
            try self.editor_host.mergeChanges(self.play_context.scene_tree);
        } else {
            // Restore snapshot
            try self.editor_host.loadScene(self.backup_scene.?);
        }

        self.play_context.deinit();
    }
};
```

---

## Import pipeline hot reload

When an asset's source file changes (e.g. a `.png` texture), Crucible's import
pipeline:

1. Detects the change via file watcher.
2. Re-reads the `.import` sidecar for import settings.
3. Calls `EditorHost.reimport(path)` which triggers Nexus's `ResourceDB.invalidate`.
4. The `ResourceDB` re-imports, re-decodes (via zGameLib), and re-uploads to GPU.
5. `ReloadEventBus` propagates the new resource to all consumers.
6. Crucible's asset dock refreshes the thumbnail.

```ascii
File changed   Crucible        Nexus Engine        zGameLib         GPU
───────────   ─────────       ────────────        ────────        ─────
  hero.png ──► watcher ──► ResourceDB       ──► zassets.decode
                  │         invalidate             Image
                  │              │                    │
                  │              ▼                    │
                  │         re-import ◄───────────────┘
                  │              │
                  │         ReloadEventBus ──► RenderingServer ──► vkCmd
                  │              │                 update descriptors
                  ▼              ▼
            thumbnail     SceneNode re-bind
            refresh       mesh/tex handles
```

---

## Editor UI hot reload

Crucible itself is built on Dear ImGui. ImGui is **naturally hot-reloadable**:
the UI is rebuilt from scratch every frame. Changing a panel layout, a color
scheme, or a docking configuration takes effect on the next frame automatically.

| Editor UI element | Reload behavior |
|-------------------|-----------------|
| Docking layout | Saved to `.ini` — reloaded on next launch or `ImGui::LoadIniSettingsFromDisk` |
| Inspector fields | Re-read from scene tree every frame (ImGui native) |
| Asset thumbnails | Re-request from `ResourceDB` when `ResourceReloaded` fires |
| Theme / style colors | `ImGui::GetStyle()` → mutable struct → next frame draws new colors |
| Fonts | `ImGui::GetIO().Fonts->Clear()` + rebuild → `ImGui::NewFrame` picks up changes |

This is one of the strongest arguments for immediate-mode UI in an editor:
**there is no retained widget tree to patch.** Hot reload of the editor's own
UI is essentially free.

### Style reload in Crucible

```zig
// Pseudocode — Crucible theme manager
pub fn reloadStyle(style_path: []const u8) void {
    const toml = parseTomlFile(style_path);
    var s = ImGui.getStyle();
    s.colors[ImGuiCol_WindowBg]   = toml.getVec4("window_bg");
    s.colors[ImGuiCol_TitleBg]    = toml.getVec4("title_bg");
    s.frameRounding               = toml.getFloat("frame_rounding");
    // Next frame renders with the new style — no patching needed
}
```

---

## Editor ↔ runtime communication pattern

When Crucible and Nexus Engine are in the same process, the communication
pattern is a **direct function call** through `EditorHost`. This avoids the
complexities of IPC, serialization, and sync that plague detached-editor
architectures.

```ascii
CRUCIBLE                        NEXUS ENGINE
────────                        ────────────
File watcher ──► EditorHost.reimport(path) ──► ResourceDB.invalidate
                                                   │
Editor asset dock ◄── ResourceReloaded ────────────┘
                        (ReloadEventBus)
```

For a future detached-editor mode (editor in a separate process), this same
pattern would serialize over a socket or shared memory — but that is **out of
scope for v1**.

---

## Comparison with other editors

| Editor | File watching | Play-in-editor | UI hot reload |
|--------|---------------|----------------|---------------|
| **Godot** | Built-in `EditorFileSystem` — scans on focus, file system dock | Same-process; scene copy; "editing while playing" optional | Custom retained UI — some properties need restart |
| **Unity** | AssetDatabase — `Refresh()` on focus change | Same-process; Enter Play Mode (options to disable domain reload) | UIToolkit needs re-import; IMGUI immediate (inspector) |
| **Unreal** | `FDirectoryWatcher` — live update in Content Browser | **SIE** (Simulate In Editor), **PIE** (Play In Editor), **VR PIE** | Slate retained — some changes recompile on the fly |
| **Crucible** | OS file watcher → `EditorHost` | Same-process; scene fork; shared ResourceDB | ImGui — free (immediate mode) |

---

## Summary

| Crucible feature | Mechanism | Ships |
|------------------|-----------|-------|
| File watching | OS notifications → `EditorHost` methods | v1.1.0+ |
| Resource reimport | `EditorHost.reimport` → `ResourceDB.invalidate` | v1.1.0+ |
| Scene reload | `EditorHost.reloadScene` → re-instantiate | v1.1.0+ |
| Locale reload | `EditorHost.reloadLocale` → re-resolve | v1.2.0 |
| Play-in-editor | Scene fork + shared ResourceDB | v1.0.0 (no editor UI) |
| Editor UI theme | Immediate mode — reload on next frame | v1.1.0+ |
| Detached editor mode | **Not planned** for v1 | Post-1.0 evaluation |

---

## Bibliography

- **Nexus hot reload** — [08-hot-reload-nexus-engine.md](08-hot-reload-nexus-engine.md) (event bus, ResourceDB reload)
- **zGameLib hot reload** — `../libs/zGameLib/docs/theory/08-hot-reload.md` (Tier 1 primitives)
- **Nexus Reference** — [`../Nexus_Reference.md`](../Nexus_Reference.md) §9 (EditorHost API)
- **Architecture** — [`../architecture.md`](../architecture.md) (3-tier stack)
- **Dear ImGui** — [`INI settings`](https://github.com/ocornut/imgui/blob/master/docs/FAQ.md#q-what-is-the-format-of-the-ini-settings)
- **Unreal Live Coding** — [Live Coding overview](https://docs.unrealengine.com/en-US/ProgrammingAndScripting/LiveCoding/)
- **Godot** — [EditorFileSystem](https://docs.godotengine.org/en/stable/classes/class_editorfilesystem.html)
- **Unity** — [Enter Play Mode](https://docs.unity3d.com/Manual/ConfigurableEnterPlayMode.html)
