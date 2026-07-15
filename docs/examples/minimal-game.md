# minimal-game — design

> **Version:** 1.0.0 — Alpha · [`ladder.md`](ladder.md)

## What it does

Small complete game (e.g. pong or micro platformer) using only `nexus.*` public APIs:
scene tree, input, rendering, optional ECS/physics from prior rungs. No Crucible.

## Hybrid takeaway

Proves **v1.0.0 is shippable** without editor — nodes for layout, ECS where needed.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `EditorHost` | API frozen (not required to run game) |
| `project.nexus` | minimal settings |
| All prior rungs | composed |

## Success criteria

- New developer reads examples 0.1.0→1.0.0 and understands hybrid model.
- Game builds with `zig build minimal-game` and runs without editor.

## Build

```sh
zig build minimal-game
```