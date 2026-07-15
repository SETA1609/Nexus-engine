# 01 — Scene representation: retained nodes in a modern engine

*Why Nexus Engine keeps a SceneNode hierarchy, what each node carries, and how that
differs from both classic Godot and a pure ECS engine.*

Redot's `scene/main/node.h` is the center of gravity for gameplay: parent/child
links, tree order, groups, pause inheritance, and per-node `_process` hooks.
[File 00b](00-legacy-node-scene-architecture.md) covers that architecture
in full as a reference for migration. This chapter assumes familiarity with
that model and layers the hybrid design on top.

Nexus Engine preserves that **authoring model** while leaving room for a performance plane
behind it (file 02). This chapter is about the **node side** of the hybrid.

---

## Three options we evaluated

### Option A — Pure SceneNode tree (classic Godot/Redot)

```ascii
SceneTree
 └── Player (Node3D)
      ├── MeshInstance
      ├── CollisionShape
      └── Camera3D
```

**Pros:** Matches Redot behavior; trivial to serialize; Link-editor edits a familiar
tree; scripts attach to nodes naturally.

**Cons:** Per-node virtual dispatch every frame; cache-unfriendly when thousands
of objects move; hard to SIMD/batch without ad-hoc side structures.

### Option B — Pure ECS (data-oriented only)

```ascii
World
  entities: [e0, e1, e2, …]
  components: Transform[], Velocity[], MeshHandle[], …
  systems: physics, render, animation
```

**Pros:** Excellent throughput for hot loops; clear system ordering.

**Cons:** Hierarchy is awkward (parent indices or separate graphs); editor UX
suffers; scene files become flat tables; steep curve for Godot migrants.

### Option C — Hybrid (Nexus Engine)

```ascii
SceneTree (authoritative for structure)     ECS (optional mirror)
        │                                          ▲
        └──────────── EcsBridge ───────────────────┘
```

**Pros:** Editor and serialization stay node-centric; hot paths opt into ECS
without forking the mental model.

**Cons:** Sync cost between representations; discipline required to avoid
duplicated state.

**Decision:** Option C. We study Redot's *usage* — most projects are
node-heavy with selective hot spots — and encode that in the architecture.

---

## What a SceneNode is (and is not)

A Nexus Engine `SceneNode` is **not** a copy of Redot's 1:1 C++ `Node` vtable. It is a
**minimal retained record** that grows as clean-room audits prove need.

| SceneNode **is** | SceneNode **is not** |
|------------------|----------------------|
| A place in a hierarchy (parent, children, order) | A GPU draw call |
| A host for properties, signals, scripts | A physics solver |
| A serialization unit | A Flecs entity (see file 02) |
| An editor selection target | A replacement for zGameLib math types |

### Structural pseudocode

```zig
const NodeId = u64;

const NodeFlags = packed struct(u32) {
    visible: bool = true,
    paused: bool = false,
    internal: bool = false,   // editor-only nodes, not saved
    ecs_mirrored: bool = false,
};

const EcsLink = union(enum) {
    none,
    mirrored: EcsEntityId,
};

const SceneNode = struct {
    id: NodeId,
    name: []const u8,
    parent: ?*SceneNode,
    children: ChildList,

    flags: NodeFlags,
    ecs: EcsLink,

    // Tree membership
    tree: ?*SceneTree,

    // Typed extension — MeshInstance3D, Camera3D, etc. embed SceneNode
    vtable: *const NodeVTable,
};
```

**Design choice:** composition over a single giant struct. `MeshInstance3D` holds
a `SceneNode` base (or embeds the common fields) plus mesh/material handles.
Link-editor and serializers talk to the common `SceneNode` surface; rendering server
reads typed extensions.

---

## SceneTree — the root contract

Redot's `SceneTree` owns the root viewport, pause state, and group registry.
Nexus Engine follows the same split:

```zig
const SceneTree = struct {
    root: *SceneNode,
    paused: bool,
    groups: GroupRegistry,   // name → set of NodeId

    fn changeScene(self: *SceneTree, packed: *PackedScene) Error!void,
    fn callGroup(self: *SceneTree, name: []const u8, method: []const u8, args: …) void,
    fn traverseProcess(self: *SceneTree, dt: f32) void,
    fn traversePhysicsProcess(self: *SceneTree, dt: f32) void,
};
```

### Tree order matters

Children run in **sibling order** (like Godot). ECS systems do **not** replace
this for gameplay logic that depends on ordering (e.g. `Camera3D` after `Player`
movement). When order is irrelevant and volume is high, prefer ECS systems (file 03).

```ascii
Parent._process
  ├── Child A._process
  │     └── Grandchild._process
  └── Child B._process
```

---

## Spatial nodes: Node2D and Node3D

Spatial nodes add transform hierarchy — the most common reason for parent/child
links in Redot.

```zig
const Node3D = struct {
    base: SceneNode,
    transform: Transform3D,       // local
    global_transform: Transform3D,  // cached, dirty-flagged

    fn translate(self: *Node3D, delta: Vec3) void,
    fn lookAt(self: *Node3D, target: Vec3, up: Vec3) void,
};
```

**Tier 1 boundary:** `Transform3D` uses `zgame.math` (or re-exported types).
Nexus Engine owns **dirty propagation** and **scene graph semantics** (inherit visibility,
notify rendering server on change).

When `ecs_mirrored` is set, `EcsBridge` copies transform to/from a
`Transform` component (file 02). The node remains the **authoritative** edit
target for Link-editor unless a system marks the entity as sim-driven.

---

## Signals and groups (lightweight)

Redot couples nodes via **signals** and **groups**. Nexus Engine keeps both — they are
engine semantics, not Tier 1:

```zig
// Signal — one-to-many, decoupled
player.health_depleted.connect(hud.onPlayerDied);

// Group — many-to-one broadcast
tree.callGroup("enemies", "alert", .{ player_position });
```

**Why Tier 2?** zGameLib has no concept of gameplay objects. Signals are how
SceneNodes cooperate without hard references — critical for scripting and editor
wiring.

---

## Serialization: PackedScene

Authoring artifacts are **node trees**, not ECS blobs.

```ascii
main.fscn
  [node name="Player" type="Node3D"]
    [node name="Mesh" type="MeshInstance3D" parent="."]
      mesh = ExtResource("res://hero.gltf")
```

ECS mirrors are **runtime-derived** unless a component is marked persistent (e.g.
custom gameplay component you explicitly save). Default: save nodes; rebuild ECS on
`enterTree`.

---

## When to stay on nodes only

Stay **node-only** (no ECS mirror) when:

- Subtree count is small (dozens, not thousands)
- Logic is event-driven or UI-heavy
- You need deterministic sibling order in `_process`
- The subtree is primarily for Link-editor organization (folders, markers)

Opt into ECS (file 02) when:

- You have bulk movers (projectiles, crowds, debris)
- A server already iterates arrays (physics, render instances)
- Profiling shows node traversal as hot (file 04)

---

## Link-editor's view of the tree

Link-editor (Tier 3) **primarily manipulates SceneNodes**:

- Scene dock = `SceneTree` hierarchy
- Inspector = `getPropertyList` / `setProperty` on selected node
- Reparent = `SceneNode.reparent`
- Gizmo = writes `Node3D.transform` (or ECS if sim-authoritative — see file 02)

Nexus Engine exposes a stable **EditorHost**; Link-editor never needs to own the tree.

---

## Summary

| Question | Answer |
|----------|--------|
| What is authoritative for structure? | SceneNode tree |
| What is authoritative for hot bulk sim? | ECS (when mirrored) |
| What does Tier 1 provide? | Math, GPU, files — not nodes |
| Why not pure ECS? | Editor UX + Redot parity + serialization |
| Why not pure nodes? | Scaling for physics/render/crowds |

**Next:** [`02-ecs-integration.md`](02-ecs-integration.md) — how `EcsLink` connects
to Flecs without leaking Flecs into game scripts.

---

## Bibliography

- Redot `scene/main/node.h`, `scene_tree.h` — behavioral reference (study only)
- Nexus Engine Reference — [`../Nexus_Reference.md`](../Nexus_Reference.md) §3–5