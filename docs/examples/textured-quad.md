# textured-quad — design

> **Version:** 0.2.0 · [`ladder.md`](ladder.md)

## What it does

Single `Sprite2D` (or quad node) under `SceneTree` root, textured via `ResourceDB`.
Rendered through `RenderingServer` inside `NexusApp.tick()`.

## Hybrid takeaway

**SceneNode-only** — no ECS mirror. The retained node is the draw command source.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `SceneNode` / `Node2D` | base hierarchy |
| `Sprite2D` | drawable registration |
| `ResourceDB` | load PNG → GPU handle |
| `RenderingServer` | draw instance flush |

## Scene setup (pseudocode)

```zig
var tree = app.context.scene_tree;
const root = tree.get_root();
const sprite = try nexus.Sprite2D.create(allocator, "Hero");
sprite.set_texture(try app.resources.load_texture("res://hero.png"));
try root.add_child(sprite);
```

## Build

```sh
zig build textured-quad
```