# Nexus Engine Reference
## Hybrid Game Engine Layer on zGameLib

**Version:** 2026-07-15  
**Status:** Living reference document for Tier 2 (the engine)  
**Aliases:** *Forge* (Nexus Engine); *Crucible* (Link-editor). Docs use canonical names.  
**Philosophy:** Retained SceneNodes for usability and editor friendliness; optional ECS for hot systems. Raw zGameLib access always reachable beneath.

---

## 1. What is Nexus Engine?

Nexus Engine is the **Tier 2 game engine** in our clean-room modernization of Redot. It sits between:

- **Tier 1 — zGameLib** (foundation: SDL3, Vulkan, audio, asset decode, math)
- **Tier 3 — Link-editor** (detachable editor: Dear ImGui, gizmos, inspectors)

Nexus Engine is **not** a duplicate of zGameLib. It is where **game architecture** lives: scene representation, servers, resources, scripting hooks, and the update loop that turns a window into a playable world.

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
│  TIER 2: NEXUS ENGINE (Engine — this project)                           │
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

**Key insight:** Nexus Engine is **just another consumer** of zGameLib. You can always drop through Nexus Engine into `zgame.platform`, `zgame.vk`, `zgame.Gpu`, and the rest. The engine never hides the metal.

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

**Phase 2 — evaluate pure-Zig ECS** when Flecs integration cost exceeds maintenance or we need comptime component layouts.

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

**Belongs in Nexus Engine (Tier 2):**

- `SceneNode`, `SceneTree`, signals, groups
- Resource UID, `.fscn` format, import presets (runtime side)
- `RenderingServer`, `PhysicsServer`, etc.
- Input **actions** (raw events are Tier 1)
- Scripting host, project settings

**Test:** If Mach or another engine would reuse it *without* adopting Nexus Engine's scene model, it belongs in Tier 1. If it assumes nodes, servers, or Redot-like resources, it belongs in Tier 2.

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

## 10. Future Evolution

| Stage | SceneNodes | ECS | Notes |
|-------|------------|-----|-------|
| **Now** | Full authoring | Flecs for physics + render gather | Bridge sync on transforms |
| **Next** | Same | Animation sampling, particles | More systems move to ECS phases |
| **Later** | Authoring + scripting API | Optional pure-Zig ECS | Flecs retired if comptime wins |
| **Never (by policy)** | — | Replace node tree entirely | Editor and Godot-like UX depend on hierarchy |

Performance expectations vs classic Godot-style nodes: [`theory/04-performance-considerations.md`](theory/04-performance-considerations.md).

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

Upstream foundation docs: [zGameLib theory](https://github.com/SETA1609/zGameLib/tree/main/docs/theory) and [`zGameLib Reference`](https://github.com/SETA1609/zGameLib/blob/main/docs/reference.md).

---

## 12. Getting Started (Minimal)

```zig
const zgame = @import("zgame");
const nexus = @import("nexus");

pub fn main() !void {
    var app = try nexus.NexusApp.init(.{
        .title = "My Game",
        .width = 1280,
        .height = 720,
    });
    defer app.deinit();

    // Raw Tier 1 still reachable
    const gpu = try zgame.Gpu.init(app.window, .{});

    try app.loadScene("res://main.fscn");
    while (!app.shouldClose()) {
        try app.tick();
    }
}
```

*(API aspirational — see implementation status below.)*

---

**This is the authoritative reference for Nexus Engine (Tier 2).**

Use it when building game systems, designing Link-editor integration, or deciding whether a feature belongs in zGameLib vs the engine.

Everything explicit. zGameLib always reachable. SceneNodes for humans; ECS for heat.