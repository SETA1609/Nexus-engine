# simple-movement — design

> **Version:** 0.5.0 · [`ladder.md`](ladder.md)

## What it does

`InputMap` binds `move_left`, `move_right`, `move_up`, `move_down`. A `Sprite2D`
`process` callback reads actions and updates local position.

## Hybrid takeaway

**Node `process`** is enough for single-sprite movement — ECS not required.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| `InputMap` | action → key/gamepad |
| `DisplayServer` | poll facade |
| `SceneNode` vtable | `process(dt)` override |

## Pseudocode

```zig
fn process(self: *Sprite2D, dt: f32) void {
    var vel: Vec2 = .{};
    if (self.input.is_action_pressed("move_right")) vel.x += 1;
    // ...
    self.local_position += vel.scale(move_speed * dt);
}
```

## Build

```sh
zig build simple-movement
```