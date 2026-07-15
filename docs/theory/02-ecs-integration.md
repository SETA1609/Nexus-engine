# 02 — ECS integration: the bridge pattern

*How SceneNodes connect to Flecs, what syncs when, and how Link-editor inspects both
without coupling to a specific ECS library.*

> **Release alignment:** attach **v0.3.0** (`ecs-basic`); sync policies **v0.4.0** (`hybrid-sync`).
> Crucible reads ECS via `EditorHost` at **v1.1.0+** — not direct Flecs linkage.

File 01 established the **node tree** as Nexus Engine's authoring model. This chapter
covers the **optional performance plane**: entities, components, and systems —
starting with a **thin Flecs adapter** (the **default and only planned ECS backend**
through v1.0). A native Zig ECS is **not** on the critical path — evaluate post-1.0 only if
Flecs cost or integration limits demand it.

---

## Why a bridge instead of "nodes wrapping entities" or the reverse

Three bridge patterns were considered:

| Pattern | Description | Rejected because |
|---------|-------------|------------------|
| **ECS core, nodes as façade** | Entity is truth; nodes are thin views | Breaks Link-editor-first editing; fights serialization |
| **Nodes core, ECS sidecar** | Node is truth; ECS is optional cache | **Chosen** — matches Redot UX, adds perf where needed |
| **Dual truth** | Both update independently | Sync bugs; abandoned |

Nexus Engine uses **nodes core, ECS sidecar** with explicit `EcsLink` on each `SceneNode`.

---

## Architecture

```ascii
┌─────────────────────────────────────────────────────────────┐
│  NEXUS ENGINE PUBLIC API (scripts, gameplay, Link-editor)              │
│    SceneNode · Node3D · signals · groups                     │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  EcsBridge                                                    │
│    attach / detach / sync_transforms / component_views       │
└───────────────────────────┬─────────────────────────────────┘
                            │ adapter only — Flecs types stay here
┌───────────────────────────▼─────────────────────────────────┐
│  nexus.ecs.flecs (Phase 1)                                    │
│    World · Entity · System registration                      │
└─────────────────────────────────────────────────────────────┘
```

**Rule:** Gameplay Zig and Link-editor call `EcsBridge` and `nexus.ecs` — not
`flecs.h` directly. Swapping Flecs for a native ECS later changes one module.

---

## Flecs adapter (Phase 1)

### Wrapper responsibilities

```zig
// nexus/ecs/flecs.zig — internal module (pseudocode)
pub const World = struct {
    raw: *flecs.World,

    pub fn register(self: *World, desc: SystemDesc) void,
    pub fn entityForNode(self: *World, id: NodeId) ?Entity,
    pub fn run(self: *World, phase: Phase) void,
};
```

### Standard components (engine-defined)

| Component | Purpose | Typical mirror source |
|-----------|---------|----------------------|
| `NodeRef` | `{ node_id: NodeId }` — stable link | Always when mirrored |
| `Transform` | pos/rot/scale or mat4 | `Node3D` |
| `Velocity` | linear/angular | Physics-driven bodies |
| `ColliderHandle` | id into PhysicsServer | `CollisionShape3D` |
| `DrawInstance` | batch key, material, mesh | `MeshInstance3D` |
| `SimAuthority` | enum: Node, Ecs, Physics | Sync policy |

Components are **plain data** (POD or handles). No virtual methods inside ECS.

---

## Attach and detach lifecycle

```zig
const EcsBridge = struct {
    world: *ecs.World,
    tree: *SceneTree,

    pub fn onNodeEnterTree(self: *EcsBridge, node: *SceneNode) void {
        if (!node.wantsEcsMirror()) return;

        const e = self.world.create();
        e.set(NodeRef{ .node_id = node.id });
        if (node.asNode3D()) |n3| {
            e.set(transformFrom(n3));
        }
        node.ecs = .{ .mirrored = e.id };
        node.flags.ecs_mirrored = true;
    }

    pub fn onNodeExitTree(self: *EcsBridge, node: *SceneNode) void {
        if (node.ecs == .none) return;
        self.world.destroy(node.ecs.mirrored);
        node.ecs = .none;
        node.flags.ecs_mirrored = false;
    }
};
```

**When is `wantsEcsMirror()` true?**

1. Node type opts in by default (`RigidBody3D`, `MeshInstance3D` in bulk scenes)
2. Project setting `ecs/mirror_by_default`
3. Explicit `ecs_mirror = true` in scene file
4. Runtime call `EcsBridge.attach(node)`

---

## Sync policies

The hardest part of hybrid design is **who wins** when both node and entity carry
transform state. Nexus Engine uses `SimAuthority`:

```zig
const SimAuthority = enum {
    node,      // Link-editor + scripts write node; ECS reads before systems
    ecs,       // Systems write Transform; bridge pushes to node after phase
    physics,   // PhysicsServer owns; both node and ECS updated from server
};
```

### Per-frame sync diagram

```ascii
                    ┌─────────────────┐
  Link-editor edit ──► │ Node3D.transform│ (authority = node)
                    └────────┬────────┘
                             │ pre-sync (if authority != ecs)
                    ┌────────▼────────┐
                    │ ECS Transform   │
                    └────────┬────────┘
                             │ physics / gameplay systems
                    ┌────────▼────────┐
                    │ ECS Transform   │ (authority = physics/ecs)
                    └────────┬────────┘
                             │ post-sync
                    ┌────────▼────────┐
                    │ Node3D.transform│ (for rendering tree, editor)
                    └─────────────────┘
```

```zig
pub fn syncTransformsToNodes(self: *EcsBridge) void {
    const q = self.world.query(.{ Transform, NodeRef, SimAuthority });
    for (q) |row| {
        if (row.authority == .node) continue;
        const node = self.tree.getNode(row.node_ref.node_id) orelse continue;
        if (node.asNode3D()) |n3| {
            n3.global_transform = row.transform.toGlobal(n3.parent);
        }
    }
}
```

**Cost:** O(mirrored entities). Keep mirror count to what systems need (file 04).

---

## System phases and registration

Systems do **not** run arbitrary order. Nexus Engine registers them into **phases**
aligned with the main loop (file 03):

| Phase | Examples | Reads/writes |
|-------|----------|--------------|
| `pre_physics` | Gather input samples | ECS |
| `physics` | Apply forces | Velocity, Transform |
| `post_physics` | Contact events | Signals on nodes |
| `gameplay` | AI steering | Velocity |
| `animation` | Sample zClip | Transform (skeletal) |
| `render_gather` | Build draw lists | DrawInstance |

```zig
world.register(.{
    .name = "integrate_velocity",
    .phase = .physics,
    .query = .{ Transform, Velocity },
    .run = integrateVelocity,
});
```

Node `_process` runs in the **gameplay** window **alongside** ECS gameplay
systems — ordering is documented in file 03.

---

## Node ↔ entity cardinality

| Case | Mapping |
|------|---------|
| Normal mirrored node | 1 node : 1 entity |
| `MultiMeshInstance3D` (later) | 1 node : N entities (instancing) |
| Folder `Node3D` (organizer) | 1 node : 0 entities |
| Pure ECS prefab (advanced) | 0 nodes : M entities — **editor escape hatch**, not default |

Default remains **1:1 or 0** for Link-editor simplicity.

---

## When to use nodes vs ECS (decision table)

| Scenario | Recommendation |
|----------|----------------|
| Player with camera and UI | Nodes only |
| 500 rigid bodies | Mirror bodies + shapes to ECS; physics phase |
| Forest with 10k static trees | Nodes in editor; bake to static draw batch + optional single entity |
| Menu screens | Nodes only |
| Bullet hell | Nodes spawn; pool as ECS-only entities with `NodeRef` optional |
| Cutscene markers | Nodes only |

---

## Link-editor and ECS introspection

Link-editor should **not** link Flecs. It queries Nexus Engine:

```zig
const ComponentView = struct {
    name: []const u8,
    type_id: TypeId,
    readOnly: bool,
    bytes: []const u8, // or typed getter
};

// EditorHost extension
getEcsComponents: ?*fn (node: NodeId) []ComponentView,
```

Inspector shows a collapsible **ECS** section when `ecs_mirrored`. Edits route
through Nexus Engine:

- `SimAuthority.node` → write node, bridge pushes to ECS
- `SimAuthority.ecs` → write component via `EcsBridge.setComponent`
- `SimAuthority.physics` → read-only in editor during play; edit via node when stopped

---

## Future: pure-Zig ECS (Phase 2)

Triggers to replace Flecs:

- Comptime component layouts needed for SIMD kernels
- Flecs C ABI friction in Zig build
- Desire for `@tagName`-driven systems without C metadata

Migration path:

1. Implement `nexus.ecs.native` matching `World`/`Entity` interface
2. Run bridge tests against both backends
3. Switch default in `build.zig` option `-Decs_backend=native|flecs`
4. Deprecate Flecs adapter when native passes integration suite

**SceneNode API unchanged** — only `nexus.ecs.flecs` internals swap.

---

## Anti-patterns

| Anti-pattern | Why it hurts |
|--------------|--------------|
| Mirroring every node by default | Sync tax on whole tree (file 04) |
| Gameplay scripts touching Flecs | Locks engine to adapter; breaks Link-editor abstraction |
| Two authorities without `SimAuthority` | Transform flicker, desync bugs |
| ECS for UI layout | Fighting retained-mode Control nodes |

---

## Summary

- **Bridge** = `EcsBridge` + `EcsLink` on `SceneNode`
- **Phase 1** = Flecs behind `nexus.ecs.flecs`
- **Sync** = explicit `SimAuthority` per mirrored subtree
- **Link-editor** = nodes first; ECS via `EditorHost` views

**Next:** [`03-systems-and-update-loop.md`](03-systems-and-update-loop.md) — where
node traversal and `world.run(phase)` fit in one frame.

---

## Bibliography

- Flecs — <https://www.flecs.dev/flecs/>
- Nexus Engine Reference — [`../Nexus_Reference.md`](../Nexus_Reference.md) §6–7
- File 01 — [`01-scene-representation.md`](01-scene-representation.md)