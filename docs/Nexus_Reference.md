# Nexus Reference
## Hybrid Game Engine on zGameLib (Tier 2)

**Official name:** **Nexus** (repository: `Nexus-engine`).  
**Version:** 2026-07-15  
**Status:** Living reference — API-first contract; implementation tracks [`ROADMAP.md`](ROADMAP.md)  
**Release line:** `0.0.x` (bootstrap) → `0.1.0` (`clear-color`) → … → `1.0.0` (alpha)  
**Aliases:** *Forge* (runtime); *Crucible* (editor, Tier 3).  
**Philosophy:** SceneNodes for authoring; Flecs-backed ECS for hot paths; opinionated immediate-mode tool UI; example-driven releases. Raw `zgame.*` always reachable.

### Finalized architecture decisions

| Area | Decision |
|------|----------|
| **ECS** | **Flecs adapter** first (`nexus.ecs.flecs`); evaluate native Zig ECS later only if integration cost or performance demands |
| **UI** | **Immediate mode** for tools (Crucible ImGui, optional debug); **semi-retained** scene UI only when necessary; in-game draw via zGameLib **2D batcher** |
| **ImGui in zGameLib** | **Optional**, implemented **toward the end** of Tier 1 roadmap — not a core dependency |
| **Examples** | Each version ships **≥1 proving example** (`zig build <name>`) — see [`examples/ladder.md`](examples/ladder.md) |
| **Localization** | Nexus-only; data-oriented; `.po` → build-time JSON/binary; runtime API **detailed design TBD** (v1.2.0) |
| **Crucible** | Docs in [`crucible/README.md`](crucible/README.md); separate repo **may** spin out later |
| **zGameLib** | Minimal core; optional modules late; **fonts after ImGui** |

### Implementation status (July 2026)

| API area | Doc status | Code status | Ships in |
|----------|------------|-------------|----------|
| `NexusApp` / `NexusContext` | Specified §4.1 | Bootstrap `main.zig` only | **0.1.0** |
| `SceneTree` / `SceneNode` | Specified §4–5 | Not implemented | **0.2.0** |
| `EcsBridge` / Flecs adapter | Specified §6 | Not implemented | **0.3.0–0.4.0** |
| `RenderingServer` | Specified §4.3 | Not implemented | **0.1.0** |
| `InputMap` / `DisplayServer` | Specified §4.3 | Not implemented | **0.5.0** |
| `PhysicsServer` | Specified §4.3 | Not implemented | **0.9.0** |
| `EditorHost` | Specified §9 | Not implemented | **1.0.0** freeze |
| `zgame.zimgui` (via `-DimGui`) | Specified §13 | Not implemented | **1.1.0+** Crucible (zGameLib ships `zimgui` late) |
| `LocalizationSystem` | Specified §14 (high-level) | Not implemented | **1.2.0** — API TBD |

**Examples:** design docs in [`docs/examples/`](examples/); source lands per version column.

---

## 1. What is Nexus?

**Nexus** is the **Tier 2 game engine** in our clean-room modernization of Redot. It sits between:

- **Tier 1 — zGameLib** (lean foundation: SDL3, Vulkan, optional modules late)
- **Tier 3 — Crucible** (detachable editor: immediate-mode Dear ImGui; docs in this repo for now)

Nexus is **not** a duplicate of zGameLib. It is where **game architecture** lives: scene representation, Flecs-backed ECS bridge, servers, resources, and the update loop that turns a window into a playable world.

**Development model:** incremental, **example-driven** — every minor release adds a runnable
example that proves the new capability (see [`ROADMAP.md`](ROADMAP.md)).

We study Redot/Godot **behavior and public APIs**, then re-implement only what is actually used — in idiomatic Zig, with `zig build`, Vulkan-only rendering, and no GDScript.

### The 3-tier model

```ascii
┌──────────────────────────────────────────────────────────────────┐
│  TIER 3: LINK-EDITOR (Editor)                                       │
│    • Immediate-mode UI (Dear ImGui style)                        │
│    • Edits SceneNode hierarchy; inspects ECS when present        │
│    • Detachable — works via EditorHost, not baked into Nexus Engine     │
└────────────────────────────┬─────────────────────────────────────┘
                             │ EditorHost API
┌────────────────────────────▼─────────────────────────────────────┐
│  TIER 2: NEXUS (this project — Nexus-engine repo)                  │
│    • Hybrid SceneNode tree + optional ECS bridge                 │
│    • Servers: render, audio, physics, navigation, text           │
│    • Resources, scene format, project settings, scripting        │
│    • Ships games without Link-editor                                │
└────────────────────────────┬─────────────────────────────────────┘
                             │ zgame.* (re-exports + thin helpers)
┌────────────────────────────▼─────────────────────────────────────┐
│  TIER 1: zGAMELIB (Foundation)                                 │
│    • platform · vk · Gpu · FrameRing · (planned) audio/assets    │
│    • Raw-first — usable standalone to ship small games           │
└──────────────────────────────────────────────────────────────────┘
```

**Key insight:** Nexus is **just another consumer** of zGameLib. You can always drop through into `zgame.platform`, `zgame.vk`, `zgame.Gpu`, and the rest. The engine never hides the metal.

---

## 2. High-Level Architecture

```ascii
                         ┌─────────────┐
                         │  Link-editor   │  Tier 3
                         │  (Editor)   │
                         └──────┬──────┘
                                │ EditorHost
┌───────────────────────────────▼──────────────────────────────────┐
│                         FORGE RUNTIME                             │
│  ┌─────────────┐  ┌──────────────┐  ┌─────────────────────────┐ │
│  │ NexusApp    │  │ Project      │  │ ResourceDB              │ │
│  │ (main loop) │  │ Settings     │  │ (load/cache/UID)        │ │
│  └──────┬──────┘  └──────────────┘  └─────────────────────────┘ │
│         │                                                         │
│  ┌──────▼──────────────────────────────────────────────────────┐ │
│  │ SCENE LAYER (hybrid)                                         │ │
│  │   SceneTree ──► SceneNode hierarchy (authoring + gameplay)   │ │
│  │        │                                                      │ │
│  │        └──► EcsBridge ──► Flecs world (hot systems)          │ │
│  └──────┬──────────────────────────────────────────────────────┘ │
│         │                                                         │
│  ┌──────▼──────────────────────────────────────────────────────┐ │
│  │ SERVERS (Redot-style, swappable backends)                    │ │
│  │   RenderingServer · AudioServer · PhysicsServer · …          │ │
│  └──────┬──────────────────────────────────────────────────────┘ │
└─────────┼────────────────────────────────────────────────────────┘
          │ explicit calls only — no Tier 1 types in server internals
┌─────────▼────────────────────────────────────────────────────────┐
│  zGAMELIB (Tier 1)                                                │
│    platform · Gpu · FrameRing · swapchain · zclip · (zaudio…)    │
└──────────────────────────────────────────────────────────────────┘
```

### Design principles

| Principle | What it means in Nexus Engine |
|-----------|------------------------|
| **Raw-first** | Every server is implemented *on top of* zGameLib primitives; `zgame` remains importable from game code |
| **Servers over monoliths** | Rendering, audio, physics are independent modules with dummy backends for headless/tests |
| **Explicit over implicit** | Vulkan-only graphics path; no hidden GL fallback |
| **Hybrid by default** | SceneNodes are the authoring model; ECS is opt-in per subtree or component |
| **Flecs first** | ECS starts as a thin adapter; native Zig ECS is a later evaluation, not v1 default |
| **Immediate-mode tools** | Crucible and debug UI use ImGui-style immediate mode; game UI uses batcher draw |
| **Example-driven** | Each version ships docs + at least one proving example |
| **Clean-room** | Redot informs *behavior*, not code; we port only proven-in-practice features |

---

## 3. Hybrid SceneNode + ECS Design

Nexus Engine deliberately rejects both extremes:

| Approach | Strength | Weakness | Nexus decision |
|----------|----------|----------|----------------|
| **Pure SceneNode tree** (classic Godot) | Editor-friendly, intuitive parent/child, easy serialization | Deep trees + per-node `_process` scale poorly for thousands of movers | **Keep** as the primary authoring model |
| **Pure ECS** | Cache-friendly bulk updates, great for physics/particles/culling | Poor match for hierarchical editing, unfamiliar to Godot users | **Use** behind a bridge for hot paths |
| **Hybrid (Nexus Engine)** | Nodes for structure; ECS for systems that need it | Two representations to sync | **Chosen** — sync is explicit and localized |

### Mental model

```ascii
Authoring & gameplay API          Performance plane
────────────────────────          ─────────────────
SceneNode tree                    ECS entities (optional)
  Player                            e_player (transform, velocity)
    Sprite                            e_sprite (draw batch id)
    CollisionShape                    e_collider (shape handle)
         │                                    ▲
         └──────── EcsBridge (1:1 or 1:0) ─────┘
```

- **Every gameplay-facing API** speaks in SceneNodes (like Redot `Node`).
- **Hot systems** (physics integration, bulk culling, particle sim) read/write ECS.
- **EcsBridge** keeps node and entity in sync — or detaches when a subtree opts out.

See [`theory/01-scene-representation.md`](theory/01-scene-representation.md) and [`theory/02-ecs-integration.md`](theory/02-ecs-integration.md) for the full treatment.

---

## 4. Core Components

### 4.1 Runtime

| Component | Responsibility |
|-----------|----------------|
| **NexusApp** | Process lifetime: init zGameLib platform, register servers, run main loop, shutdown |
| **NexusContext** | Per-run state: active scene, time, input map, server registry |
| **Main loop** | Fixed/variable tick, node traversal, ECS system phases, server flush (see theory/03) |

### 4.2 Scene layer

| Component | Responsibility |
|-----------|----------------|
| **SceneTree** | Root of all nodes; pause mode; groups; scene change |
| **SceneNode** | Base type: parent/child, name, visibility, transform, signals |
| **Node2D / Node3D** | Spatial nodes; transform hierarchy |
| **EcsBridge** | Maps `SceneNode` ↔ Flecs entity; sync policy |
| **PackedScene** | Serialized subtree for instancing |

### 4.3 Servers

Servers mirror Redot's `servers/` layout — **engine APIs**, not Tier 1 primitives:

| Server | Tier 1 it consumes | Tier 2 it provides |
|--------|-------------------|-------------------|
| **DisplayServer** | `zgame.platform` | Windows, input routing, cursors, clipboard facade |
| **RenderingServer** | `Gpu`, `FrameRing`, shaderc, (future) draw2d | Meshes, materials, viewports, draw lists, culling |
| **AudioServer** | (future) `zgame.audio` | Buses, effects, 3D attenuation |
| **PhysicsServer** | Jolt (adapter) | Bodies, shapes, queries, areas |
| **NavigationServer** | Recast/Detour (adapter) | Nav meshes, path queries |
| **TextServer** | (future) `zgame.font` | Font discovery, shaping, atlas |

**Boundary rule:** Servers call zGameLib for *device work* (GPU submit, decode buffer, play sample). They own *engine policy* (what to draw, which bus, which collision layer).

### 4.4 Resources

| Component | Responsibility |
|-----------|----------------|
| **Resource** | Base refcounted asset (path, UID, load state) |
| **ResourceLoader / Saver** | Path → typed resource; import hooks |
| **ResourceDB** | Cache, dependency tracking, hot-reload signals |

Details: [`theory/05-resource-and-asset-management.md`](theory/05-resource-and-asset-management.md).

### 4.5 Editor seam (Tier 3)

| Component | Responsibility |
|-----------|----------------|
| **EditorHost** | Trait Link-editor implements against: selection, undo, property edit, play-in-editor |
| **EditorInterface** | Stable C/Zig ABI surface for detached editor builds |

Link-editor primarily mutates **SceneNodes**. When a node has an ECS mirror, the editor can show read-only or editable ECS component fields through the bridge.

---

## 5. SceneNode — Structural Sketch

Nexus Engine's `SceneNode` is intentionally smaller than Redot's `Node` — we grow it as usage audits demand.

```zig
// Pseudocode — illustrative, not final API
const SceneNode = struct {
    id: NodeId,
    name: []const u8,
    parent: ?*SceneNode,
    children: std.ArrayList(*SceneNode),
    flags: NodeFlags,        // visible, paused, internal
    ecs: EcsLink,            // .none | .mirrored(Entity) | .ecs_only (rare)

    // Lifecycle hooks (override per subtype)
    fn enterTree(self: *SceneNode, tree: *SceneTree) void,
    fn exitTree(self: *SceneNode) void,
    fn process(self: *SceneNode, delta: f32) void,      // variable timestep
    fn physicsProcess(self: *SceneNode, delta: f32) void, // fixed timestep

    // Introspection for Link-editor + serialization
    fn getPropertyList(self: *const SceneNode) []PropertyDesc,
    fn setProperty(self: *SceneNode, name: []const u8, value: Variant) Error!void,
};
```

**Why retained nodes?**

1. **Link-editor** edits a tree humans understand — parent under `Player`, drag `Sprite` as child.
2. **Serialization** maps naturally to nested scene files (`.fscn` successor).
3. **Redot parity** — most shipped games use node callbacks, not raw ECS.
4. **Gradual perf** — opt into ECS per subtree without rewriting the whole project.

---

## 6. ECS Bridging Strategy (Summary)

**Phase 1 — Flecs adapter** (`nexus.ecs.flecs`):

- Thin Zig wrapper; no Flecs types leak into public SceneNode API.
- `EcsBridge.attach(node)` creates entity with stable `NodeId` component.
- Standard components: `Transform`, `Velocity`, `ColliderHandle`, `DrawInstance`.
- Systems registered per **phase** (physics, render gather, animation sample).

**Phase 2 (post-1.0, only if needed) — evaluate native Zig ECS** when Flecs integration cost exceeds maintenance, ABI friction hurts ports, or comptime layouts become necessary. Not planned for initial hybrid releases.

**When to use ECS vs stay on nodes:**

| Use SceneNode only | Add ECS mirror |
|--------------------|----------------|
| UI subtrees, cutscene directors, low-count logic | Physics bodies, crowds, projectiles |
| Nodes with simple `_process` | Particle fields, procedural foliage |
| Editor-only helpers | Frustum culling buckets, GPU instance lists |

Full bridge protocol: [`theory/02-ecs-integration.md`](theory/02-ecs-integration.md).

---

## 7. Hybrid Update Loop (Summary)

One frame, simplified:

```zig
// Pseudocode
fn tick(ctx: *NexusContext, dt: f32, fixed_dt: f32) void {
    ctx.display.pollEvents();
    ctx.input.update();

    // 1) Fixed phase — physics + node physicsProcess
    while (ctx.accumulator >= fixed_dt) {
        ctx.physics.server.step(fixed_dt);
        ctx.scene_tree.traversePhysicsProcess(fixed_dt);
        ctx.ecs.runSystems(.physics);
        ctx.accumulator -= fixed_dt;
    }

    // 2) Variable phase — gameplay
    ctx.scene_tree.traverseProcess(dt);
    ctx.ecs.runSystems(.gameplay);

    // 3) Servers flush — rendering, audio
    ctx.ecs.runSystems(.render_gather);
    ctx.rendering.server.render(ctx.active_viewport);
    ctx.audio.server.update();

    // 4) Late sync — node ← ecs for mirrored transforms (if policy says so)
    ctx.ecs_bridge.syncTransformsToNodes();
}
```

See [`theory/03-systems-and-update-loop.md`](theory/03-systems-and-update-loop.md).

---

## 8. Tier 1 ↔ Tier 2 Boundary

**Belongs in zGameLib (Tier 1):**

- Window, events, timers (SDL3 adapter)
- Vulkan instance/device/swapchain/`FrameRing`
- Image decode, glTF parse, miniaudio playback
- Math primitives (`Vec3`, `Mat4`, `Quat`)
- zstd, ENet packets
- **Dear ImGui** (`zimgui`) — optional via `-DimGui`; **late** Tier 1 module (after 2D batcher)
- **Fonts** (`zfont`) — optional; **after** `zimgui` in Tier 1 roadmap

**Belongs in Nexus Engine (Tier 2):**

- `SceneNode`, `SceneTree`, signals, groups
- Resource UID, `.fscn` format, import presets (runtime side)
- `RenderingServer`, `PhysicsServer`, etc.
- Input **actions** (raw events are Tier 1)
- Scripting host, project settings
- **`LocalizationSystem`** — data-oriented locale tables; `lookup()` / `tr()`; loads compiled JSON from `res://locale/`
- **`nexus-locale` build step** — `.po` (translator source) → JSON at export time
- Semi-retained in-game UI (`Control` nodes, future) — only where scene serialization/layout requires it; drawn via batcher

**Belongs in Crucible (Tier 3) only:**

- Dear ImGui as a **hard dependency** — docks, inspector, viewport chrome
- `.po` authoring UI, locale preview, compile trigger — runtime JSON load stays Nexus

**Test:** If Mach or another engine would reuse it *without* adopting Nexus Engine's scene model, it belongs in Tier 1. If it assumes nodes, servers, or Redot-like resources, it belongs in Tier 2. If it is editor chrome that mutates the scene through `EditorHost`, it belongs in Tier 3.

---

## 9. Link-editor (Tier 3) Interaction

```ascii
Link-editor UI                    Nexus runtime
────────────                   ─────────────
Scene tree dock    ──read──►   SceneTree root
Inspector          ◄─write──   SceneNode properties
Viewport gizmo     ──write──►  Transform (node or ECS)
ECS debug panel    ──read──►   Flecs world via EcsBridge
Play button        ──call──►  EditorHost.playScene()
```

**EditorHost** (implemented by Nexus Engine, consumed by Link-editor):

```zig
const EditorHost = struct {
    getSceneTree: *fn () *SceneTree,
    getSelection: *fn () []NodeId,
    setProperty: *fn (node: NodeId, name: []const u8, value: Variant) Error!void,
    beginUndoTransaction: *fn (label: []const u8) TransactionId,
    playInEditor: *fn () Error!void,
    stopInEditor: *fn () void,
    // Optional ECS introspection
    getEcsComponents: ?*fn (node: NodeId) []ComponentView,
};
```

Link-editor does **not** link Flecs directly in the preferred layout — it asks Nexus Engine for ECS views. That keeps the adapter swappable.

---

## 10. Release Evolution (semantic versions)

Aligned with [`ROADMAP.md`](ROADMAP.md) and [`examples/ladder.md`](examples/ladder.md).

| Version | SceneNodes | ECS | Example |
|---------|------------|-----|---------|
| **0.1.0** | Empty tree | — | `clear-color` |
| **0.2.0** | Hierarchy + drawables | — | `textured-quad`, `node-hierarchy` |
| **0.3.0** | Same | Attach mirror | `ecs-basic` |
| **0.4.0** | Same | Sync transforms | `hybrid-sync` |
| **0.5.0–0.6.0** | Input, camera | Optional mirror | `simple-movement`, `camera` |
| **0.7.0** | Spawner node | ECS-only particles | `particles` |
| **0.9.0** | Rigid bodies | Physics authority | `physics-ball` |
| **1.0.0** | Authoring API frozen | Flecs default adapter | `minimal-game` |
| **1.1.0+** | Crucible edits tree | Inspector reads bridge | Tier 3 repo |
| **1.2.0** | Localized `Control` props | — | `LocalizationSystem` + `.po`→JSON |

**Later (post-1.0):** evaluate pure-Zig ECS behind same `World` interface; animation
sampling on ECS; optional scripting host; RTL layout with Control theme system.

**Never (by policy):** replace SceneNode tree with pure ECS for authoring.

Performance expectations: [`theory/04-performance-considerations.md`](theory/04-performance-considerations.md).

---

## 11. Theory Documentation — Reading Order

Read [`theory/README.md`](theory/README.md), then:

| # | File | Topic |
|---|------|-------|
| 01 | [`01-scene-representation.md`](theory/01-scene-representation.md) | SceneNode design; why hybrid |
| 02 | [`02-ecs-integration.md`](theory/02-ecs-integration.md) | Flecs bridge; sync policies |
| 03 | [`03-systems-and-update-loop.md`](theory/03-systems-and-update-loop.md) | Tick phases; node + ECS ordering |
| 04 | [`04-performance-considerations.md`](theory/04-performance-considerations.md) | When hybrid wins; pitfalls |
| 05 | [`05-resource-and-asset-management.md`](theory/05-resource-and-asset-management.md) | Resources vs zGameLib decode |
| 06 | [`06-ui-and-localization.md`](theory/06-ui-and-localization.md) | Immediate-mode UI; batcher HUD; `LocalizationSystem` |

Upstream foundation docs: [zGameLib theory](https://github.com/SETA1609/zGameLib/tree/main/docs/theory), [`zGameLib Reference`](https://github.com/SETA1609/zGameLib/blob/main/docs/reference.md), and [zGameLib ImGui (`-DimGui`)](../zGameLib/docs/imgui.md).

---

## 12. Getting Started

**Today (bootstrap):** `zig build` + `zig build run` — raw zGameLib window loop in `src/main.zig`.

**Target (v0.1.0+):** first example [`clear-color`](examples/clear-color.md):

```zig
const nexus = @import("nexus");

pub fn main() !void {
    var app = try nexus.NexusApp.init(.{
        .title = "clear-color",
        .width = 1280,
        .height = 720,
    });
    defer app.deinit();

    while (!app.shouldClose()) {
        try app.tick(); // poll → sim phases → RenderingServer → present
    }
}
```

**Learning path:** examples per version in [`examples/ladder.md`](examples/ladder.md) ·
theory in [`theory/README.md`](theory/README.md).

```zig
// Raw Tier 1 remains available from game code when a server is in the way:
const zgame = @import("zgame");
// zgame.Gpu, zgame.platform, …
```

---

**This is the authoritative reference for Nexus (Tier 2).**

Use it when building game systems, designing Link-editor integration, or deciding whether a feature belongs in zGameLib vs the engine.

Everything explicit. zGameLib always reachable. SceneNodes for humans; ECS for heat.

---

## 13. Immediate Mode UI Strategy

Nexus takes an **opinionated immediate-mode** approach (Handmade Hero / Casey Muratori): **use
immediate mode when you need UI** — especially tools. Use **semi-retained** scene UI only when
serialization, editor inspection, or stable layout truly requires it. Dear ImGui is the tool-layer
choice for Crucible; **not** the in-game widget stack.

Full design: [`theory/06-ui-and-localization.md`](theory/06-ui-and-localization.md) ·
[zGameLib `imgui.md`](../zGameLib/docs/imgui.md).

### Three UI lanes

```ascii
LANE              TECHNOLOGY                    WHEN
────              ──────────                    ────
Editor (T3)       Dear ImGui (required)         Crucible — panels, inspector, gizmos
In-game (T2)      zGameLib 2D batcher           HUD, menus, Control nodes — NO ImGui
Debug (T2/opt)    ImGui OR debug draw           debug-ui example (v0.8.0)
```

| Layer | ImGui | In-game UI |
|-------|-------|------------|
| zGameLib | Optional `-DimGui` (**late** roadmap) | **2D batcher** first (sprites, text — planned) |
| Nexus | `debug-ui` overlay (debug draw first) | `RenderingServer` + semi-retained `Control` nodes |
| Crucible | **Required** (when editor ships) | Edits scene data only — does not draw game HUD |

**Why optional and late in zGameLib?** Tier 1 stays minimal; 2D batcher and core adapters ship first. ImGui lands when Crucible needs it (~Nexus v1.1.0+).

**Why required in Crucible?** The editor is immediate-mode tool UI — rebuilding panels each frame
is the right model (Handmade Hero / explicit tooling practice).

**Why not ImGui for in-game UI?** Gameplay UI needs serialization, localization keys, draw
batching, and stable layout — the **2D batcher** path under `RenderingServer` is explicit and
performance-friendly.

### Enabling ImGui (tools only)

```sh
zig build debug-ui -DimGui=true       # Nexus dev overlay (optional)
zig build crucible -DimGui=true     # Tier 3 — always on
```

### Tool UI frame contract

After the scene pass, optional ImGui records into the same `FrameRing` buffer (load-op `LOAD`):

```zig
if (ctx.config.enable_imgui) {
    zimgui.processPlatformEvents(&ctx.imgui, ctx.display);
    zimgui.newFrame(&ctx.imgui, .{ .dt = dt, .size = ctx.drawable_size });
    ctx.tool_ui.draw(&ctx.imgui);  // Crucible editor OR Nexus debug stats
    try zimgui.render(&ctx.imgui, ctx.gpu.currentCmd(), ctx.render_pass);
}
```

### In-game UI (batcher path)

```zig
const label = ctx.localization.lookup(.{ .key = "UI_PLAY" }) orelse "UI_PLAY";
ctx.rendering.drawText2d(batch, label, .{ .x = 16, .y = 16 });
```

### vs other engines (UI)

| Engine | Editor UI | Game UI | Nexus choice |
|--------|-----------|---------|--------------|
| Godot | Custom in-engine toolkit | `Control` nodes | ImGui editor (T3) + batcher HUD (T2) |
| Unity | UIToolkit / IMGUI | uGUI / UI Toolkit | Detach editor; no UIToolkit in player |
| Unreal | Slate | UMG | Same split — tools vs shipped UI |
| Bevy | External editors | `bevy_ui` retained | SceneNode `Control` + explicit batcher |

---

## 14. Localization (high level — data-oriented)

Localization lives in **Nexus (Tier 2)**, not zGameLib. Direction: **data-oriented** compiled
tables that gameplay systems query — not ICU, not i18next, not runtime `.po` parsing.

Ship target: **v1.2.0**. **Detailed API** (`LocalizationSystem` schema, `tr()` helpers, ECS
integration) will be specified during implementation — this section records **decisions**, not
final signatures.

### Pipeline

```ascii
locale/src/*.po  ──►  nexus-locale (build)  ──►  res://locale/*.json
                                                          │
                                                          ▼
                                              LocalizationSystem.lookup(key)
                                              ECS systems · Control nodes · tr()
```

| Stage | Format | Role |
|-------|--------|------|
| Authoring | `.po` / `.pot` | Translators, Crucible PO workflow |
| Compile | `nexus-locale` | Validate PO → emit JSON (optional `.nloc` later) |
| Runtime | `CompiledLocaleData` resource | Flat entries; plural rules baked |
| Query | `LocalizationSystem` | `lookup()`, `lookupPlural()`; `tr()` helper |

**Why not in zGameLib?** Locales assume `project.nexus`, scene keys, and `ResourceDB` — engine
concepts. zGameLib keeps UTF-8 I/O only.

**Why `.po` → JSON?** PO for CAT tooling; JSON (or binary) for mmap-friendly O(1) cold start.
No gettext parser, ICU, or i18next in the player.

### Direction (API TBD)

- **Query model** — systems call into `LocalizationSystem` (or read pre-resolved string handles).
- **Godot familiarity** — expect `tr()`-style helpers; exact names frozen at v1.2.0.
- **ECS** — resolve strings on locale change, not every frame (data-oriented).
- **Crucible** — `.po` editing workflow; compile step stays in Nexus build/export.

Illustrative direction only:

```zig
// Pseudocode — shapes may change before v1.2.0 ships
const text = ctx.localization.resolve("UI_PLAY") orelse "UI_PLAY";
```

### vs other engines (localization)

| Engine | Model | Nexus |
|--------|-------|-------|
| **Godot / Redot** | `TranslationServer`; CSV/PO at runtime | Compile first; `LocalizationSystem` query |
| **Unity** | Localization tables as assets; `LocalizedString` refs | `.po` source → compiled JSON assets |
| **Unreal** | `LOCTEXT` gather → `.locres` compile | `nexus-locale` → JSON; explicit lookup, no `FText` stack |
| **Bevy** | Community JSON asset loaders | First-party Tier 2 system beside `ResourceDB` |

**Learn:** Unity's data-driven keys, Unreal's compile-before-ship, Bevy's immutable locale assets.  
**Avoid:** Godot's runtime format parsing; ICU weight; monolithic editor+i18n coupling.

**Trade-offs:** explicit export compile step; no magic CSV drop-in at runtime in v1.2.0.  
**Gains:** small player, fast lookup, PO vendor workflow, headless unit tests without GPU.