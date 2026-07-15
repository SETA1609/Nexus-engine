# node-hierarchy — design

> **Version:** 0.2.0 · [`ladder.md`](ladder.md)

## What it does

Three-node tree: `Player` → `Sprite` + `Marker`. Demonstrates reparent, local/world
transform propagation, pause/visibility flags. May use flat color quads (no texture required).

## Hybrid takeaway

Hierarchy is **authoritative for structure** — the pattern Crucible will edit later.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `SceneTree` | add/remove/reparent, deferred delete |
| Transform | parent motion affects children |
| `NodeFlags` | visible, paused |

## Scene (pseudocode)

```zig
const player = try nexus.Node2D.create(allocator, "Player");
const sprite = try nexus.Node2D.create(allocator, "Sprite");
const marker = try nexus.Node2D.create(allocator, "Marker");
try player.add_child(sprite);
try player.add_child(marker);
try root.add_child(player);

player.set_position(.{ .x = 100, .y = 50 }); // sprite + marker follow
```

## Build

```sh
zig build node-hierarchy
```