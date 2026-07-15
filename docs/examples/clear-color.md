# clear-color — design

> **Version:** 0.1.0 · **Rung:** first Nexus example · [`ladder.md`](ladder.md)

## What it does

Opens a window, runs `NexusApp.tick()` each frame, clears the swapchain via
`RenderingServer` — **no `SceneNode` drawables**. Proves Tier 2 owns the loop.

## Hybrid takeaway

ECS and scene tree are initialized but empty. The hybrid model starts from a
running engine, not from raw zGameLib calls in `main`.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `NexusApp` | init / tick / deinit |
| `RenderingServer` | live + dummy backend |
| `SceneTree` | empty root only |
| `NexusContext` | timestep accumulator |

## Frame loop

```zig
var app = try nexus.NexusApp.init(.{ .title = "clear-color", .width = 800, .height = 600 });
defer app.deinit();

while (!app.shouldClose()) {
    try app.tick(); // poll → (empty sim) → clear → present
}
```

## Tier 1 used

`zgame.platform`, `zgame.Gpu`, `zgame.FrameRing` — via `RenderingServer` only.

## Build

```sh
zig build clear-color
zig build run-clear-color   # when wired
```