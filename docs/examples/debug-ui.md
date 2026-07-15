# debug-ui — design

> **Version:** 0.8.0 · [`ladder.md`](ladder.md)

## What it does

Toggleable dev overlay: FPS, node count, mirrored ECS count, `syncTransformsToNodes` ms.
Two implementation paths:

| Path | ImGui | When to use |
|------|-------|-------------|
| **Default** | No | CI-friendly; `RenderingServer` debug text/quads |
| **Rich panels** | zGameLib `-DimGui=true` | Histograms, collapsible sections, live graphs |

This is **not Crucible** — no scene tree dock, inspector, or play mode. The full editor is
Tier 3 and **hard-depends** on Dear ImGui (immediate-mode **tool** UI).

**Not in-game UI:** gameplay HUDs use the zGameLib **2D batcher** via `RenderingServer` — ImGui
is never required for shipped game UI. See [`theory/06`](../theory/06-ui-and-localization.md).

## Hybrid takeaway

Makes **bridge sync cost visible** — educates when to mirror vs stay node-only.

## ImGui integration (optional)

When zGameLib `zimgui` is available:

```sh
zig build debug-ui -DimGui=true
```

Frame order (see [`theory/06-ui-and-localization.md`](../theory/06-ui-and-localization.md)):

1. Scene sim + `RenderingServer` pass (load-op `CLEAR` / scene draw).
2. `zimgui.newFrame` → draw stats window → `zimgui.render` on same command buffer (load-op `LOAD`).
3. Present via `FrameRing`.

Nexus does not link ImGui in `minimal-game` or other release-oriented examples unless
explicitly requested.

## What building it forces

| Component | Milestone |
|-----------|-----------|
| Frame profiler | per-phase timings |
| Debug draw | text/quads on top of scene |
| Optional `zimgui` hook | end-of-frame pass in `NexusApp` |

## Build

```sh
zig build debug-ui
zig build debug-ui -DimGui=true   # when zGameLib zimgui ships
```

## See also

- [`../theory/06-ui-and-localization.md`](../theory/06-ui-and-localization.md)
- [`../Nexus_Reference.md`](../Nexus_Reference.md) §13
- [zGameLib `imgui.md`](../../zGameLib/docs/imgui.md)