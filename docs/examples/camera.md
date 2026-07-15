# camera — design

> **Version:** 0.6.0 · [`ladder.md`](ladder.md)

## What it does

`Camera2D` child under root follows a moving `Sprite2D`. `RenderingServer` applies
camera transform to viewport draw list.

## Hybrid takeaway

Camera is a **SceneNode** — editor-friendly; render gather may read ECS later for culling.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `Camera2D` | projection + offset |
| `RenderingServer` | active camera / viewport |
| `Node3D` | optional smoke for 3D matrix path |

## Build

```sh
zig build camera
```