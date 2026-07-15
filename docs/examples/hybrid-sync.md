# hybrid-sync — design

> **Version:** 0.4.0 · [`ladder.md`](ladder.md) · Theory: [02](../theory/02-ecs-integration.md), [03](../theory/03-systems-and-update-loop.md)

## What it does

One node mirrored to ECS. An ECS system writes `Transform` each frame (e.g. circular
motion). `syncTransformsToNodes` updates the node's world matrix; `Sprite2D` draws at
the synced position.

## Hybrid takeaway

Demonstrates **sync policy** — who is authoritative when (`ecs_authoritative` for sim).

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `EcsBridge` | `syncTransformsToNodes`, policies |
| `NexusApp.tick` | ECS phases + sync step |
| Components | `Transform`, `DrawInstance` |

## Tick slice

```ascii
ECS gameplay system  →  writes Transform on entity
render_gather        →  collects DrawInstance
syncTransformsToNodes →  node.world = f(entity)
RenderingServer      →  draw sprite at node transform
```

## Build

```sh
zig build hybrid-sync
```