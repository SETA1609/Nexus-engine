# physics-ball — design

> **Version:** 0.9.0 · [`ladder.md`](ladder.md)

## What it does

`RigidBody2D` or `RigidBody3D` node mirrored to ECS. Fixed timestep physics step;
`PhysicsServer` writes transforms; bridge syncs to nodes; sprite draws ball.

## Hybrid takeaway

**Sim authority on ECS/physics server** — nodes remain the gameplay/edit surface.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `PhysicsServer` | step + shapes |
| Fixed tick | accumulator in `NexusApp` |
| Bridge | post-physics sync |

## Build

```sh
zig build physics-ball
```