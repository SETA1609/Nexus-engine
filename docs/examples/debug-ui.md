# debug-ui — design

> **Version:** 0.8.0 · [`ladder.md`](ladder.md)

## What it does

Toggleable overlay: FPS, node count, mirrored ECS count, `syncTransformsToNodes` ms.
Optional richer panel via zGameLib `-DimGui` when available.

## Hybrid takeaway

Makes **bridge sync cost visible** — educates when to mirror vs stay node-only.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| Frame profiler | per-phase timings |
| Debug draw | text/quads on top of scene |

**Not Crucible** — dev overlay only; editor remains Tier 3.

## Build

```sh
zig build debug-ui
```