# The Nexus example ladder

Each release adds **one primary engine capability** (sometimes two small examples
that exercise the same version). Every example is a complete app: import `nexus`,
build a scene (when applicable), call `NexusApp.tick()`.

**Pay-for-what-you-use:** early examples do not link Flecs, physics, or editor code.
Later rungs add subsystems explicitly.

## Rungs

| Ver | Example | New capability | Hybrid lesson | Status |
|-----|---------|----------------|---------------|--------|
| **0.1.0** | **clear-color** | `NexusApp` + `RenderingServer` | Engine owns loop; empty tree OK | planned |
| **0.2.0** | **textured-quad** | `Sprite2D` / quad + `ResourceDB` | Nodes draw things | planned |
| **0.2.0** | **node-hierarchy** | `SceneTree` reparent, transforms | Retained hierarchy | planned |
| **0.3.0** | **ecs-basic** | `EcsBridge.attach` | Opt-in mirror | planned |
| **0.4.0** | **hybrid-sync** | Transform sync policies | Two planes, one truth | planned |
| **0.5.0** | **simple-movement** | `InputMap` + `process` | Gameplay on nodes | planned |
| **0.6.0** | **camera** | `Camera2D` / viewport | View through tree | planned |
| **0.7.0** | **particles** | ECS-only entities | Heat without N nodes | planned |
| **0.8.0** | **debug-ui** | Profiler overlay | Observe hybrid cost | planned |
| **0.9.0** | **physics-ball** | `PhysicsServer` + bridge | Sim on ECS, UX on nodes | planned |
| **1.0.0** | **minimal-game** | End-to-end sample | Ship without Crucible | planned |

## What is NOT linked (modularity)

| Through version | Not required |
|-----------------|--------------|
| ≤ 0.2.0 | Flecs, physics, audio, editor |
| ≤ 0.4.0 | Physics, particles, Crucible |
| ≤ 0.8.0 | Crucible, `.fscn` serializer |
| 1.0.0 | Crucible (still separate at 1.1.0+) |

## Three jobs, every example

| Job | Meaning |
|-----|---------|
| **Integration test** | Nexus + zGameLib path unit tests cannot reach |
| **Usage reference** | Canonical `import nexus` + server registration |
| **Teaching rung** | One new concept per version — matches theory docs |

## Decoupling checks (future)

When Flecs lands (0.3.0+), add optional `nm` or compile checks that examples
without `ecs_mirrored` nodes do not pull physics symbols. Pattern mirrors
[zGameLib decoupling](https://github.com/SETA1609/zGameLib/blob/main/docs/examples/ladder.md#decoupling-checks-nm).

## Why this order

1. **clear-color** before nodes — prove loop + GPU before scene complexity.
2. **node-hierarchy** before ECS — learn retained model first (theory/01).
3. **ecs-basic** before **hybrid-sync** — attach lifecycle before sync (theory/02).
4. **particles** after **hybrid-sync** — ECS-only pattern needs bridge context (theory/04).
5. **debug-ui** before **physics** — profile bridge cost before adding sim.
6. **minimal-game** last in Tier 2 — combines rungs without Crucible.

## See also

[`vision.md`](vision.md) · [`mission.md`](mission.md) · [`../ROADMAP.md`](../ROADMAP.md)