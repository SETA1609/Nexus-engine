# 03 — Systems and the update loop

*One frame from `pollEvents` to `present`: fixed timestep, node traversal, ECS
phases, and server flush — in a deterministic order.*

Nexus Engine's `NexusApp` owns the loop. It consumes zGameLib's **platform poll** and
**GPU frame ring** (Tier 1) but decides **when** nodes, ECS, and servers run
(Tier 2). This chapter is the clock diagram for the hybrid architecture.

---

## Two clocks: display vs simulation

Like Redot, Nexus Engine separates:

| Clock | Driven by | Used for |
|-------|-----------|----------|
| **Variable `dt`** | Wall time between frames | Rendering, `_process`, animation playback |
| **Fixed `fixed_dt`** | Accumulator (e.g. 1/60 s) | Physics, `_physics_process`, deterministic sim |

```zig
var accumulator: f32 = 0;
accumulator += dt;

while (accumulator >= fixed_dt) {
    runFixedStep(ctx, fixed_dt);
    accumulator -= fixed_dt;
}
runVariableStep(ctx, dt);
```

**Tier 1 boundary:** `platform.getTicks()` or equivalent provides time. Nexus
Engine chooses policy (max substeps, clamp `dt` on spiral-of-death).

---

## Full frame pipeline (ASCII)

```ascii
┌──────────────────────────────────────────────────────────────────┐
│ FRAME N                                                           │
├──────────────────────────────────────────────────────────────────┤
│ 1. INPUT     platform.pollEvents() → DisplayServer → InputMap    │
│ 2. FIXED×k   physics server · physicsProcess · ECS.physics       │
│ 3. VARIABLE  process · ECS.gameplay · timers · signals           │
│ 4. SERVERS   ECS.render_gather · RenderingServer · AudioServer   │
│ 5. SYNC      EcsBridge.syncTransformsToNodes()                   │
│ 6. GPU       zgame.FrameRing begin → record → end → present      │
│ 7. LATE      deferred deletes · profiler flush                   │
└──────────────────────────────────────────────────────────────────┘
```

Steps 1–5 are Nexus Engine. Step 6 delegates to **zGameLib** (`Gpu`, `FrameRing`).
Link-editor "play in editor" uses the **same** pipeline inside a child `NexusContext`.

---

## Phase 1 — Input and platform

```zig
fn phaseInput(ctx: *NexusContext) void {
    ctx.display.pollEvents();
    if (ctx.display.shouldClose()) ctx.running = false;

    ctx.input.update(); // raw events → actions (Tier 2 mapping)
}
```

**Tier 1:** raw `KeyDown`, mouse position.  
**Tier 2:** `InputMap` ("jump" → Space, gamepad A).

---

## Phase 2 — Fixed step (may run 0..N times)

```zig
fn runFixedStep(ctx: *NexusContext, fixed_dt: f32) void {
    if (ctx.tree.paused) return;

    // 2a — Physics server (Jolt or dummy)
    ctx.physics.server.step(fixed_dt);

    // 2b — Node fixed callbacks (tree order)
    ctx.tree.traversePhysicsProcess(fixed_dt);

    // 2c — ECS systems registered for .physics
    ctx.ecs.runSystems(.physics);

    // 2d — Push physics transforms into mirrored ECS / nodes
    ctx.physics.syncToBridge(&ctx.ecs_bridge);
}
```

### Node traversal (physics)

Same sibling order as Redot `_physics_process`:

```zig
fn traversePhysicsProcess(node: *SceneNode, dt: f32) void {
    if (node.isPausedInHierarchy()) return;
    node.vtable.physicsProcess(node, dt);
    for (node.children) |child| traversePhysicsProcess(child, dt);
}
```

Only nodes that **override** `physicsProcess` pay dispatch cost — empty base is
no-op (not virtual call to empty function if vtable points to shared stub).

---

## Phase 3 — Variable step (once per frame)

```zig
fn runVariableStep(ctx: *NexusContext, dt: f32) void {
    if (ctx.tree.paused) return;

    // 3a — Node gameplay
    ctx.tree.traverseProcess(dt);

    // 3b — ECS gameplay systems (AI, steering, …)
    ctx.ecs.runSystems(.gameplay);

    // 3c — Animation (may sample zClip — Tier 1 — apply to nodes/ECS)
    ctx.animation.server.advance(dt);
    ctx.ecs.runSystems(.animation);

    // 3d — Flush queued signals (same frame semantics as Godot)
    ctx.signals.dispatchQueued();
}
```

### Ordering: nodes vs ECS in gameplay

**Default policy (documented, configurable per project):**

1. `traverseProcess` (depth-first, sibling order)
2. `ECS.gameplay` systems

Rationale: scripts on nodes behave like Godot `_process` running before generic
systems unless you register `SystemOrder.afterNodes`. Advanced projects can
invert via project setting `ecs/gameplay_before_nodes`.

---

## Phase 4 — Server flush (render + audio)

Rendering is **not** done inside `MeshInstance3D._process`. Redot separates
**scene** from **RenderingServer**; Nexus Engine keeps that seam.

```zig
fn phaseServers(ctx: *NexusContext) void {
    // Gather draw instances from ECS + visible node walk
    ctx.ecs.runSystems(.render_gather);
    ctx.rendering.server.syncFromScene(&ctx.tree); // non-mirrored legacy path

    // Build passes, cull, record commands into FrameRing cmd buffer
    ctx.rendering.server.render(ctx.main_viewport);

    ctx.audio.server.mix();
}
```

### Tier 1 vs Tier 2 in rendering

| Step | Tier |
|------|------|
| Decide *what* is visible, materials, passes | Nexus Engine `RenderingServer` |
| Allocate GPU buffers, record `vkCmd*` | Nexus Engine calls zGameLib helpers |
| Acquire image, fences, present | zGameLib `FrameRing` |

```zig
// RenderingServer tail — delegates metal
if (try ctx.frame_ring.begin(&ctx.swapchain, extent)) |frame| {
    try ctx.rendering.recordPasses(frame.cmd);
    try ctx.frame_ring.end(&ctx.swapchain, frame, .{ .color = true });
}
```

---

## Phase 5 — ECS → node sync

After simulation and before editor readback (and before next frame's node edits):

```zig
ctx.ecs_bridge.syncTransformsToNodes();
```

Skip when no mirrored entities or when `SimAuthority.node` everywhere.

---

## Phase 6 — GPU present (Tier 1)

Owned by zGameLib — see upstream theory file 06 (`FrameRing`). Nexus Engine passes the
command buffer filled by `RenderingServer`.

---

## Phase 7 — Late cleanup

```zig
ctx.deferred_nodes.flush();  // free nodes queued on exitTree
ctx.resources.collectGarbage(); // refcount epoch
```

---

## Pause and scene tree changes

| Event | Behavior |
|-------|----------|
| `tree.paused = true` | Skip process phases; rendering may continue (configurable) |
| `changeScene()` | `exitTree` on old root → destroy ECS entities → load new `PackedScene` → `enterTree` |
| Play-in-editor | Link-editor clones or subroots scene; same loop in `EditorHost` sandbox |

```zig
fn changeScene(tree: *SceneTree, packed: *PackedScene) !void {
    if (tree.root) |old| {
        old.exitTreeRecursive(&tree.ecs_bridge);
    }
    tree.root = try packed.instantiate();
    tree.root.enterTreeRecursive(tree, &tree.ecs_bridge);
}
```

---

## Headless and server-only mode

Nexus Engine supports **no window** (dedicated server):

- zGameLib: optional headless platform or no `FrameRing`
- Skip phase 6 GPU; keep phases 2–3 for sim
- `RenderingServer` uses dummy backend (Redot pattern)

---

## Complete pseudocode: `NexusApp.tick`

```zig
pub fn tick(self: *NexusApp) !void {
    const dt = self.clock.delta();
    try phaseInput(&self.ctx);

    self.ctx.accumulator += dt;
    const max_steps = 8;
    var steps: u32 = 0;
    while (self.ctx.accumulator >= self.fixed_dt and steps < max_steps) : (steps += 1) {
        runFixedStep(&self.ctx, self.fixed_dt);
        self.ctx.accumulator -= self.fixed_dt;
    }

    runVariableStep(&self.ctx, dt);
    try phaseServers(&self.ctx);
    self.ctx.ecs_bridge.syncTransformsToNodes();
    try phaseGpuPresent(&self.ctx); // zgame.FrameRing
    phaseLate(&self.ctx);
}
```

---

## Link-editor: same loop, extra hooks

When Link-editor presses Play:

```ascii
EditorHost.playInEditor()
  → clone scene or mark sandbox root
  → NexusApp.tick() loop (possibly reduced viewport)
  → EditorHost.canInspectLiveNodes() = true
EditorHost.stopInEditor()
  → tear down sandbox ECS world
  → restore edited scene snapshot
```

Link-editor does **not** reimplement physics or rendering — it hosts the same
`NexusApp` pipeline.

---

## Summary

| Layer | Runs in loop |
|-------|--------------|
| zGameLib | poll, GPU acquire/submit/present |
| SceneNodes | `physicsProcess`, `process` (tree order) |
| ECS | phased systems (`physics`, `gameplay`, `render_gather`, …) |
| Servers | physics step, rendering, audio mix |
| EcsBridge | enter/exit tree, transform sync |

**Next:** [`04-performance-considerations.md`](04-performance-considerations.md) —
what this costs vs pure Godot nodes and how to stay fast.

---

## Bibliography

- zGameLib theory 06 — Frame ring (upstream)
- Redot `scene/main/scene_tree.cpp` — pause and process groups (behavioral reference)
- File 02 — [`02-ecs-integration.md`](02-ecs-integration.md)