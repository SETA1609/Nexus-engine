# particles — design

> **Version:** 0.7.0 · [`ladder.md`](ladder.md) · Theory: [04-performance](../theory/04-performance-considerations.md)

## What it does

One `ParticleSpawner` `SceneNode` (editor-visible). On spawn, creates **1000+ ECS-only**
entities with `Transform` + `Velocity` — no `SceneNode` per particle. Sim in ECS;
`render_gather` draws quads.

## Hybrid takeaway

Classic hybrid win: **structure in nodes, heat in ECS**.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| ECS systems | particle sim phase |
| `render_gather` | bulk draw from ECS |
| Spawner node | emits entities, not children |

## Anti-pattern avoided

```zig
// DON'T: 1000 SceneNode children
// DO:     1 Spawner node + 1000 ECS entities
```

## Build

```sh
zig build particles
```