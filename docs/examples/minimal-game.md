# minimal-2d-game — design

> **Version:** 1.0.0 — 2D Alpha · [`ladder.md`](ladder.md)  
> **Build target:** `minimal-2d-game` (alias: `minimal-game` during migration)

## What it does

Small **complete 2D game** (e.g. micro platformer, top-down, or pong-plus) using only
`nexus.*` public APIs: `Node2D` / `Sprite2D` scene tree, `Camera2D`, input, 2D rendering,
optional ECS/physics from prior rungs. No Crucible. At least one WASM or data-only mod loads.

## Hybrid takeaway

Proves **v1.0.0 is shippable** as a **2D-first** title without editor — nodes for layout,
ECS where needed. 3D nodes are out of scope until Nexus v2.0.0.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `EditorHost` | API frozen (not required to run game) |
| `project.nexus` | minimal settings |
| All prior rungs | composed |

## Success criteria

- New developer reads examples 0.1.0→1.0.0 and understands hybrid model.
- Game builds with `zig build minimal-2d-game` and runs without editor.

## Build

```sh
zig build minimal-2d-game
```