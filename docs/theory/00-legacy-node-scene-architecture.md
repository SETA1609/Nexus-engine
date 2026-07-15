# 00 — Legacy node-only scene architecture (Redot)

*Reference documentation of the Redot / Godot4 scene tree architecture as it exists
today — the system Nexus Engine's hybrid SceneNode + ECS model (file 01 onward) is
designed to supersede. This file exists so implementors understand what "legacy
mode" means, what assumptions the Link-editor carries forward, and which guarantees
the hybrid model must preserve during migration.*

---

## 1. Purpose and scope

This document describes the **unmodified Redot engine** scene architecture as a
single, self-contained model. It is **not** a proposal. It is a record of the
system that Nexus Engine replaces — the "before" picture.

**Use this file when:**
- Porting a Redot project to Nexus Engine and deciding what maps directly.
- Reaching a design decision where the hybrid model (01) differs from legacy
  and you need to know what legacy did.
- Implementing the Link-editor's scene dock, inspector, or reparent operations
  that must remain compatible with the old serialization format.

---

## 2. Core class hierarchy

The entire scene system rests on a four-level inheritance chain rooted at `Object`:

```
Object                              — identity, signals, properties, scripting
  └── RefCounted                    — reference-counted memory management
        └── Resource                — loadable/saveable asset with path + caching
              └── PackedScene       — serialized scene template (.tscn / .scn)
  └── Node                          — base class for everything in the scene tree
        ├── CanvasItem              — 2D drawable (transform, visibility, texturing)
        │     ├── Node2D            — 2D spatial (position, rotation, scale)
        │     └── Control           — UI (rect, layout, theming, input)
        ├── Node3D                  — 3D spatial (position, rotation, scale)
        └── Viewport                — render surface, camera, audio listener
              ├── Window            — OS-level window
              └── SubViewport       — in-window render target
```

**Key rule:** every object in a scene is a `Node`. There is no `Entity`, no
`Component`, no flat data table. Type differentiation is entirely through C++
inheritance and the `GDCLASS` / `ClassDB` registration system.

---

## 3. SceneTree — the runtime root

**Source:** `scene/main/scene_tree.h`, `scene/main/scene_tree.cpp`

`SceneTree` inherits from `MainLoop` (the OS-level game loop interface). It is
the single orchestrator that owns:

| Member | Type | Role |
|--------|------|------|
| `root` | `Window*` | Root viewport/window. Always present. |
| `current_scene` | `Node*` | The currently active scene root (child of `root`). |
| `group_map` | group registry | Named groups → set of node pointers. |
| `delete_queue` | deletion queue | Deferred `memdelete` via `queue_delete()`. |
| `multiplayer` | `MultiplayerAPI*` | Networking root. |

### Scene change flow

```
change_scene_to_file(path)
  → ResourceLoader::load(path) → Ref<PackedScene>
  → change_scene_to_packed(packed_scene)
      → packed_scene->instantiate()      // creates Node* tree from serialized data
      → root->remove_child(current)      // NOTIFICATION_EXIT_TREE on old scene
      → queue new node for deferred add
      → _flush_scene_change()
          → memdelete(old scene)
          → root->add_child(new)          // NOTIFICATION_ENTER_TREE + NOTIFICATION_READY
```

Scene changes are **deferred**: the old scene leaves immediately, the new scene
enters at a safe point in the frame. No "loading screen" mechanism is baked in.

### Processing pipeline (every frame)

1. `iteration_prepare()`
2. `physics_process(dt)` — calls `_process(true)` for physics groups
3. `iteration_end()`
4. `process(dt)` — calls `_process(false)` for idle groups

Node `_process` / `_physics_process` callbacks are dispatched via group iteration,
not recursive walk — but the *notification propagation* (enter_tree, ready, exit_tree)
walks the subtree recursively.

---

## 4. Node — the universal building block

**Source:** `scene/main/node.h` (~937 lines)

`Node` is the base class for **everything** that lives in the scene tree. Every
node carries all of the following in a private `Data` struct:

### 4.1 Tree topology fields

| Field | Type | Purpose |
|-------|------|---------|
| `parent` | `Node*` | Owning parent in the tree (null for root). |
| `children` | `HashMap<StringName, Node*>` | Direct children, keyed by name. |
| `children_cache` | `LocalVector<Node*>` | Order-preserving child list (mirrors the map). |
| `name` | `StringName` | Must be unique among siblings. |
| `depth` | `int` | Integer depth from root. |
| `tree` | `SceneTree*` | Owning scene tree (null if orphan). |
| `viewport` | `Viewport*` | Nearest viewport ancestor (cached). |

### 4.2 Scene instance / ownership fields

| Field | Type | Purpose |
|-------|------|---------|
| `owner` | `Node*` | Scene instance boundary — the root of the `PackedScene` this node was instantiated from. |
| `owned` | `List<Node*>` | Reverse — nodes this node owns. |
| `scene_file_path` | `String` | Path to the `.tscn` this node was instantiated from. |
| `instance_state` | `Ref<SceneState>` | Packed scene data for this instance. |
| `inherited_state` | `Ref<SceneState>` | Scene inheritance data. |

**Ownership vs. parent-child:** `owner` marks scene instance boundaries (which
nodes "belong" to a PackedScene). `parent` is the tree hierarchy. They can
differ for editor-instantiated editable children.

### 4.3 Groups and processing

| Field | Type | Purpose |
|-------|------|---------|
| `grouped` | `HashMap<StringName, GroupData>` | Groups this node belongs to. |
| `process_mode` | `ProcessMode` | Inherit / Pausable / Always / Disabled. |
| `multiplayer_authority` | `int` | Network authority peer. |
| `internal_mode` | `InternalMode` | Front/back internal node (editor-only). |

### 4.4 Key API surface

**Tree management:**
- `add_child(Node*, ...)` — append child; triggers `_propagate_enter_tree()`.
- `remove_child(Node*)` — detach; triggers `_propagate_exit_tree()`.
- `get_parent()` / `get_children()` / `get_child(int)` / `get_child_count()`
- `get_node(NodePath)` — navigate relative or absolute paths.
- `reparent(Node*)` — move to new parent preserving world transform.
- `replace_by(Node*)` — swap self with another node in-tree.

**Notifications (lifecycle):**
- `NOTIFICATION_ENTER_TREE` — node was added to active tree.
- `NOTIFICATION_EXIT_TREE` — node was removed from active tree.
- `NOTIFICATION_READY` — subtree is fully entered; safe to access children.
- `NOTIFICATION_PROCESS` — per-frame idle update (if `set_process(true)`).
- `NOTIFICATION_PHYSICS_PROCESS` — per-fixed-step physics update.

**Groups:**
- `add_to_group(name, persistent)` — join a named group.
- `remove_from_group(name)` — leave.
- `is_in_group(name)` — membership test.

**SceneTree-level group API:**
- `call_group(name, method, args)` — invoke method on all members.
- `notify_group(name, notification)` — send notification.
- `get_nodes_in_group(name)` — enumerate members.

### 4.5 Propagation internals

Notification propagation is handled by private recursive methods:

- `_propagate_enter_tree()` — recurses subtree setting `tree` pointer, caching
  `viewport`, increments orphan/node counters, emits `NOTIFICATION_ENTER_TREE`.
- `_propagate_ready()` — recurses subtree emitting `NOTIFICATION_READY` in
  depth-first order AFTER the entire subtree has entered.
- `_propagate_exit_tree()` — recurses subtree clearing `tree` pointer, emitting
  `NOTIFICATION_EXIT_TREE`.
- `_propagate_notification(what)` — broadcasts any notification to subtree.

This recursive walk is **the** hot path for tree mutations and is a primary
motivation for the ECS bridge in Nexus Engine.

---

## 5. The "scene" concept: PackedScene and SceneState

**Source:** `scene/resources/packed_scene.h`, `scene/resources/packed_scene.cpp`

There is **no** runtime `Scene` class. A "scene" is a *template* stored as a
`PackedScene` resource (`.tscn` file on disk). When instantiated, it produces a
tree of `Node` objects.

### PackedScene

```cpp
class PackedScene : public Resource {
    Ref<SceneState> state;   // serialized scene data
};
```

| Method | Purpose |
|--------|---------|
| `pack(Node* root)` | Serialize live node tree into state. |
| `instantiate(GenEditState)` | Deserialize → `Node*` tree. |
| `can_instantiate()` | Validity check. |

### SceneState — the serialization format

`SceneState` holds all data needed to reconstruct a node tree:

| Field | Contents |
|-------|----------|
| `names` | Interned string table (`Vector<StringName>`). |
| `variants` | Interned variant table (`Vector<Variant>`). |
| `node_paths` | Interned path table (`Vector<NodePath>`). |
| `nodes` | Array of `NodeData` descriptors. |
| `connections` | Array of signal connections. |

Each `NodeData` stores: `parent`, `owner`, `type` (class name), `name`,
`instance` (nested PackedScene reference), child `index`, `properties`
(name/value pairs), and `groups`.

The `instantiate()` flow:
```
iterate nodes[]
  → ClassDB::instantiate(type)     // create empty node by class name
  → set properties from stored pairs
  → re-establish parent-child edges
  → reconnect signals
  → honor editable children (owner inheritance)
```

### PackedScene → runtime flow

```
.tscn file on disk
  → ResourceLoader::load(path)
  → Ref<PackedScene>
  → packed_scene->instantiate()
  → Node* (root with full subtree, owner links)
  → SceneTree::root->add_child(node)
  → node is now "in the tree" and receives ENTER_TREE + READY
```

---

## 6. The runtime scene tree

At runtime the hierarchy looks like:

```
SceneTree
  └── root (Window / Viewport)
        ├── current_scene (Node subclass — Node2D, Node3D, Control, …)
        │     ├── child_1
        │     │     ├── grandchild_1
        │     │     └── grandchild_2
        │     └── child_2
        ├── CanvasLayer (if any)
        └── nodes added programmatically
```

Every node in the tree has `data.tree != nullptr`. Nodes outside the tree are
**orphans** — tracked by `Node::orphan_node_count` for leak detection.

**Sibling order matters.** Children are stored in insertion order (`children_cache`)
and iteration follows that order. This order is deterministic and is used by
rendering order, input priority, and `_process` dispatch.

---

## 7. Signals

Signals are inherited from `Object` (not reinvented in Node):

```cpp
struct Connection {
    ::Signal signal;
    Callable callable;
    uint32_t flags;   // CONNECT_DEFERRED, CONNECT_PERSIST, CONNECT_ONE_SHOT, …
};
```

Each `Object` maintains:
- `signal_map` — per-signal slot lists (`HashMap<StringName, SignalData>`).
- `connections` — flat list of all connections.

**Key API:**
- `connect(signal, callable, flags)` — wire a signal to a callable.
- `disconnect(signal, callable)` — unwire.
- `emit_signal(name, ...)` — fire.

Signals are serialized in `SceneState::ConnectionData` and re-established during
`PackedScene::instantiate()`. The `CONNECT_PERSIST` flag distinguishes
connections that survive scene saves from editor-only wiring.

**Node overrides** the base `connect`/`emit_signal` in debug builds with thread
guards (asserts the caller is on the main thread).

---

## 8. Groups

Groups decouple communication without hard references:

- **`Node::add_to_group(name, persistent)`** — registers the node in the
  `SceneTree::group_map` under the given name.
- **`SceneTree::call_group(name, method, args)`** — invokes a method on every
  member.
- **`SceneTree::notify_group(name, notification)`** — sends a notification.
- **`SceneTree::get_nodes_in_group(name)`** — returns the member list.

Groups support flags: `GROUP_CALL_DEFAULT`, `GROUP_CALL_REVERSE`,
`GROUP_CALL_DEFERRED`, `GROUP_CALL_UNIQUE`.

Typical usage: `"enemies"`, `"cameras"`, `"gui"` — fire-and-forget broadcast
replacing manual iteration.

---

## 9. Ownership model

The `owner` pointer defines **scene instance boundaries** — which nodes belong
to a given PackedScene root. When a `.tscn` is instantiated:

- The root node has `owner = nullptr`.
- All descendant nodes have `owner` set to the root.
- `PackedScene::instantiate()` takes a `GenEditState` that controls whether
  `owner` is the root (runtime) or the edited node (editor).

**`is_owned_by_parent()`** returns true when `owner` == `parent` (common for
editor-created children). The reverse `owned` list and `owned_unique_nodes` map
allow efficient ownership queries.

Ownership is orthogonal to the parent-child tree: a node can be a child of one
node but owned by another (editable children in the editor).

---

## 10. Viewport and window hierarchy

**Source:** `scene/main/viewport.h`, `scene/main/window.h`

`Viewport` (inherits `Node`) is the visual entry point:
- Holds a `RID` in the `RenderingServer`.
- Manages 2D/3D cameras, audio listeners, physics picking, GUI input routing.
- `Window` (inherits `Viewport`) = OS-level window.
- `SubViewport` (inherits `Viewport`) = in-window render target.

`SceneTree::root` is a `Window`. Every node in the tree caches its nearest
`Viewport` ancestor in `Node::data.viewport` (updated during
`_propagate_enter_tree`).

---

## 11. Key architectural patterns

### 11.1 "Scene is a template, not a class"

There is no `Scene` runtime class. A `.tscn` file = `PackedScene` resource =
serialized `SceneState`. Instantiating it produces `Node` objects. The mental
model is "a scene is a subtree of nodes saved to disk."

### 11.2 Single tree, global singleton

`SceneTree::get_singleton()` provides global access to the tree. All nodes share
one root, one group registry, one set of timers/tweens. This is simple but
precludes isolated scene contexts without manual effort.

### 11.3 Everything is a Node

Scene, camera, light, mesh instance, UI button, timer, audio player — all are
`Node` subclasses. There is no separation between "data" and "game object."
Composition is achieved through child nodes and signals, not components.

### 11.4 Ownership is the serialization boundary

`owner` is the key that the editor uses to determine which nodes belong to which
scene file. When saving, nodes whose `owner` matches the scene root are included;
foreign-owned nodes are external references. This is the backbone of the nested
scene system.

### 11.5 Recursive notification propagation

All lifecycle notifications (`ENTER_TREE`, `READY`, `EXIT_TREE`, `PROCESS`,
`PHYSICS_PROCESS`) are propagated via recursive walks of the subtree. This is
simple and correct but becomes a bottleneck with deep trees or thousands of nodes.

### 11.6 Deterministic sibling order

Child order is insertion-order and stable. Rendering, input, and process dispatch
all follow sibling order. This is critical for UI (draw order) and gameplay
(camera after player movement).

---

## 12. What legacy does NOT have

The legacy architecture has no concept of:

- **ECS (Entity Component System).** No entities, no components, no systems.
  All game logic is in `Node._process` / `_physics_process` virtual methods.
- **Data-oriented storage.** Nodes are pointer-chased, vtable-dispatched objects.
  No SoA layouts, no archetypes, no batch iteration.
- **Separation of concerns.** A `Node` is simultaneously a transform provider,
  a script host, a signal hub, a network authority, and a pause-inheritance
  participant — all in one struct.
- **Flat iteration.** There is no efficient way to iterate "all nodes with a
  Transform and a Mesh" without walking the full tree and performing dynamic
  casts (or using groups, which must be manually maintained).

These gaps are what the hybrid model (file 01) addresses by adding an ECS bridge
behind the retained node tree.

---

## 13. Migration concerns

When porting a Redot project to Nexus Engine, the following legacy patterns need
attention:

| Legacy pattern | Hybrid equivalent |
|----------------|-------------------|
| `Node._process(dt)` constant polling | ECS system (or keep node if small count) |
| `get_node()` deep path navigation | Cached `NodeRef` or direct pointer; ECS query for bulk |
| Groups for broad-phase queries | ECS query with components (mirror group membership as component tag) |
| `owner`-based scene boundaries | Same — serialization still uses owner; ECS ignores it |
| `PackedScene` instantiate + add_child | Same — node tree remains authoring model |
| `queue_free()` for cleanup | Same + EcsBridge detach on EXIT_TREE |
| `emit_signal` decoupling | Same — signals remain; consider ECS events for cross-system comms |
| Deep transform hierarchy | Same for small/editor trees; flatten to local transforms + ECS for bulk |

**General rule:** The node tree is always present and authoritative for
structure. ECS is additive — you never need it to run a scene.

---

## 14. Summary

| Aspect | Legacy (Redot) | Hybrid (Nexus Engine) |
|--------|---------------|----------------------|
| Scene runtime | Tree of `Node*` objects | Tree of `SceneNode` + optional ECS mirror |
| Game logic | `_process` / `_physics_process` virtuals | Node callbacks + ECS systems |
| Composition | Child nodes + signals | Child nodes + signals + components |
| Serialization | `PackedScene` / `.tscn` | Same (node-centric) |
| Bulk iteration | Groups or tree walk | ECS queries |
| Sync cost | None (no dual model) | `EcsBridge` sync per frame (opt-in) |
| Editor model | Scene dock → tree → inspector | Same, plus ECS component views |

The hybrid model retains all of the above as **default behavior** when no ECS
mirror is active. Nodes without `ecs_mirrored` behave exactly like legacy Redot
nodes — the difference is invisible to scripts and the Link-editor.

---

## 15. Source files referenced

All paths relative to the Redot engine source root:

| File | What it defines |
|------|----------------|
| `core/object/object.h` | `Object` — root of all engine objects |
| `core/object/ref_counted.h` | `RefCounted` — reference counting |
| `core/io/resource.h` | `Resource` — loadable asset base |
| `scene/main/node.h` | `Node` — scene tree building block |
| `scene/main/scene_tree.h` | `SceneTree`, `SceneTreeTimer` |
| `scene/main/viewport.h` | `Viewport`, `SubViewport` |
| `scene/main/window.h` | `Window` |
| `scene/main/canvas_item.h` | `CanvasItem` — 2D drawable base |
| `scene/2d/node_2d.h` | `Node2D` |
| `scene/3d/node_3d.h` | `Node3D` |
| `scene/gui/control.h` | `Control` |
| `scene/resources/packed_scene.h` | `PackedScene`, `SceneState` |

---

## 16. Bibliography

- Redot engine source — `scene/main/node.h`, `scene/main/scene_tree.h`,
  `scene/resources/packed_scene.h` (study only; not shipped in Nexus Engine).
- Next: [`01-scene-representation.md`](01-scene-representation.md) — the hybrid
  SceneNode design that replaces this legacy model.
