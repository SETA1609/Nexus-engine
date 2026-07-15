# 04 — Performance considerations

*What the hybrid model costs, where it wins over pure Godot-style nodes, and
how to profile before moving more logic into ECS.*

> **Release alignment:** ECS-only particles **v0.7.0** (`particles`); profiler overlay **v0.8.0** (`debug-ui`).

Nexus Engine optimizes for **shipping Redot-like games in Zig**, not for winning synthetic
ECS benchmarks. This chapter sets honest expectations and practical rules.

---

## Baseline comparison

| Workload | Pure Redot-style nodes | Nexus hybrid | Pure ECS engine |
|----------|------------------------|--------------|-----------------|
| 50 nodes, light `_process` | Excellent | Excellent (identical if no mirror) | Overkill |
| 2k dynamic bodies | Poor (per-body nodes) | Good (ECS physics phase) | Excellent |
| 10k static meshes | OK (static culling) | Good (bake + `DrawInstance`) | Excellent |
| Deep UI tree | Good | Good | Poor editor UX |
| Rapid Link-editor edits | Good | Good (node authority) | Slower if entity-only |

**Takeaway:** Hybrid should match nodes-only when mirrors are off, and approach
ECS engines when mirrors are on for hot sets only.

---

## Cost centers in the hybrid

### 1. Per-node traversal

```ascii
Cost ≈ O(nodes with non-empty process hooks)
```

**Mitigations:**

- Shared no-op vtable for nodes without `_process`
- Disable processing on subtrees (`process_mode = disabled`)
- Move hot logic to ECS systems; leave empty nodes for structure

### 2. ECS mirror sync

```ascii
Cost ≈ O(mirrored entities) per sync direction
```

**Mitigations:**

- Mirror only subtrees that need it (file 02)
- Use `SimAuthority.physics` — one sync path from server
- Batch sync: structure-of-arrays walk, not per-entity hash lookup

### 3. Bridge attach/detach

Spikes on scene change, not steady state. **Mitigations:**

- Pool entities in Flecs
- Prefab instantiation: bulk create from template

### 4. RenderingServer gather

Classic Godot cost: iterating visible instances. Nexus Engine adds optional ECS
`render_gather` to build instance arrays without touching every node vtable.

```ascii
Without ECS gather:  walk visible MeshInstance3D nodes
With ECS gather:     iterate DrawInstance[] + frustum cull in SoA
```

---

## When hybrid beats pure nodes

Enable ECS mirror when profiling shows:

| Symptom | Likely fix |
|---------|------------|
| `traverseProcess` > 15% frame | Move bulk AI to `ECS.gameplay` |
| Physics step + node sync scattered | Centralize on `PhysicsServer` + ECS |
| Draw call setup from deep tree walk | `render_gather` system + instancing |
| Alloc churn in spawn loops | ECS pools; nodes only for "spawner" |

---

## When hybrid loses to pure ECS

Nexus Engine **accepts** that a bullet-heaven-only prototype might be faster with **no
nodes** in the hot path. Escape hatch:

```zig
// Spawner node (SceneNode) — editor-visible
// Projectiles: ECS-only entities, no SceneNode per bullet
spawnProjectile(world, transform); // no attach() per bullet
```

Link-editor sees the spawner; not every particle. Document in scene as
`@ecs_pool projectiles`.

---

## Memory layout notes

| Data | Preferred home |
|------|----------------|
| Transform hierarchy for editing | Node3D (tree) |
| 3k velocities | ECS `Velocity[]` |
| Mesh/material handles | Resource IDs; `DrawInstance` in ECS |
| String names, signals | Nodes only |

Avoid storing duplicate **large** payloads in both layers (mesh geometry stays in
`Resource`; nodes hold handles only).

---

## Threading (future)

**Phase 1:** single-threaded loop (matches early Nexus Engine). Documented order in file 03.

**Phase 2+:**

- Physics (Jolt) — worker threads inside adapter
- RenderingServer — record passes on worker; submit on main
- ECS — Flecs `multi_threaded` systems where safe
- **SceneNode tree** — main thread only for mutations; Link-editor edits main thread

**Rule:** ECS systems may read mirrored components off main thread; **node tree
mutation** and **signal dispatch** stay on main thread until proven safe.

---

## Profiling checklist

1. **Mirror count** — how many `ecs_mirrored` nodes?
2. **Process hooks** — how many non-no-op `process` / `physicsProcess`?
3. **Sync time** — `EcsBridge.syncTransformsToNodes` ms
4. **Server time** — physics vs render gather vs audio
5. **Tier 1 GPU** — still use GPU timestamps; don't blame nodes for fill-rate

Nexus Engine should ship Tracy/zig tracing hooks on:

- `traverseProcess`
- `ecs.runSystems(phase)`
- `ecs_bridge.sync`
- `rendering.server.render`

---

## Evolution path: moving systems to ECS

| Stage | Typical project |
|-------|-----------------|
| **MVP** | All gameplay in nodes; physics server only |
| **Growth** | Mirror dynamics; `render_gather` for crowds |
| **Mature** | Gameplay systems in ECS; nodes for wiring + UI |
| **Selective** | Native Zig ECS; Flecs retired |

**Never migrate:** editor structure, `PackedScene` format, signal graph — stay node-centric.

---

## Anti-patterns that look fast but aren't

| Pattern | Problem |
|---------|---------|
| Mirror entire scene "just in case" | Sync + memory for 100% of nodes |
| `_process` on every child for one timer | Use `Timer` node or ECS system |
| Duplicate mesh data on entity | Bloat; use handles |
| Skip `SimAuthority` to "avoid ceremony" | Desync bugs; expensive debugging |

---

## Summary

| Question | Guidance |
|----------|----------|
| Default perf profile? | Same as lean Godot if no mirrors |
| How to scale? | Opt-in ECS mirrors + server bulk paths |
| What to profile first? | Traversal, sync, render gather |
| Pure ECS games? | Use pools; nodes for spawners/editor only |

**Next:** [`05-resource-and-asset-management.md`](05-resource-and-asset-management.md) —
resources sit in Tier 2; decoding sits in Tier 1.

---

## Bibliography

- Godot performance docs — node processing modes (behavioral reference)
- Nexus Engine Reference — [`../Nexus_Reference.md`](../Nexus_Reference.md) §10