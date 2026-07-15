# ecs-basic — design

> **Version:** 0.3.0 · [`ladder.md`](ladder.md) · Theory: [02-ecs-integration.md](../theory/02-ecs-integration.md)

## What it does

Two `Node2D` nodes with `ecs_mirrored = true`. On `enter_tree`, `EcsBridge` creates
Flecs entities with `NodeId` component. Logs entity ids each second — **no transform sync**.

## Hybrid takeaway

ECS is a **sidecar** — gameplay code still speaks `SceneNode`; Flecs stays internal.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `nexus.ecs.flecs` | `World`, `Entity` |
| `EcsBridge` | attach / detach on tree lifecycle |
| `SceneNode.ecs` | `EcsLink.mirrored` |

## Pseudocode

```zig
sprite.flags.ecs_mirrored = true;
try root.add_child(sprite); // bridge.onNodeEnterTree → entity created

// Game code never imports flecs — only:
const eid = app.ecs_bridge.entity_for_node(sprite.id);
```

## Build

```sh
zig build ecs-basic
```