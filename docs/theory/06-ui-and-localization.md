# 06 — UI & localization: immediate-mode tools, data-oriented strings

*Opinionated immediate-mode UI for tools; semi-retained scene UI only when necessary;
in-game draw on the 2D batcher; localization as compiled data in Nexus — not zGameLib.*

> **Release alignment:** debug overlay **v0.8.0** (debug draw; ImGui when zGameLib `zimgui` lands late);
> Crucible **v1.1.0+**; localization direction **v1.2.0** (detailed API TBD at implementation).
> Crucible docs: [`../crucible/README.md`](../crucible/README.md).

---

## Two problems, three UI lanes

| Lane | UI model | Technology | Tier |
|------|----------|------------|------|
| **Editor** | Immediate mode (Casey Muratori style) | Dear ImGui via `zgame.zimgui` | Crucible (Tier 3) — **required** |
| **In-game** | Custom batched draw (semi-retained `Control` only if needed) | zGameLib **2D batcher** | Nexus — **no ImGui** |
| **Debug** | Immediate mode when useful | Debug draw first; ImGui when `zimgui` ships (late Tier 1) | Nexus `debug-ui` |

| Problem | Tier | Rationale |
|---------|------|-----------|
| **Tool UI** (panels, inspectors) | zGameLib optional · Crucible required | Tools benefit from immediate mode; shipped games do not |
| **Localized strings** | Nexus `LocalizationSystem` | Scene keys, compile pipeline, locale policy — engine concepts |

```ascii
  CRUCIBLE (Tier 3)          NEXUS (Tier 2)              zGAMELIB (Tier 1)
  ─────────────────          ──────────────              ─────────────────
  Dear ImGui REQUIRED   ◄──  EditorHost only      ◄──   zimgui (-DimGui opt)
  immediate-mode editor      LocalizationSystem          2D batcher (planned)
                             in-game UI ─────────────────► quads/glyphs/text
                             debug overlay (opt ImGui)
```

**Golden rules**

1. **Opinionated immediate mode** — prefer rebuilding tool UI each frame; semi-retained scene UI only when serialization/layout requires it.
2. **ImGui is late in zGameLib** — optional module toward end of Tier 1 roadmap; Crucible waits for it.
3. **Localization is data in Nexus** — `.po` → compile → query; detailed API TBD at v1.2.0.

---

## Part A — Immediate mode UI strategy

### The Casey Muratori split

Handmade Hero / explicit-engine practice: **immediate-mode UI is excellent for tools** that
rebuild every frame (editor panels, debug sliders, profilers). **Shipped game UI** should be
purpose-built — batched quads, atlases, layout you control — not a general widget toolkit
forced into the runtime.

Nexus applies that split across tiers:

```ascii
┌─────────────────────────────────────────────────────────────────────┐
│  IMMEDIATE MODE (tools)                                             │
│    Crucible: scene tree, inspector, viewport chrome — Dear ImGui      │
│    debug-ui: optional ImGui panels OR RenderingServer debug text    │
├─────────────────────────────────────────────────────────────────────┤
│  RETAINED / CUSTOM (game)                                           │
│    Control nodes → RenderingServer → zGameLib 2D batcher            │
│    localized labels query LocalizationSystem at layout/build time   │
└─────────────────────────────────────────────────────────────────────┘
```

### Why optional in zGameLib, required in Crucible

| Layer | ImGui | In-game UI |
|-------|-------|------------|
| **zGameLib** | Optional `-DimGui` | **2D batcher** — sprites, text, nine-slice (planned) |
| **Nexus Engine** | Optional `debug-ui` only | `Control` nodes + `RenderingServer` (not ImGui) |
| **Crucible** | **Hard dependency** | Does not draw game HUD — edits scene data only |

| Question | Answer |
|----------|--------|
| Why optional in zGameLib? | Foundation stays lean; many consumers need zero UI toolkit |
| Why required in Crucible? | Editor *is* immediate-mode panels — ImGui is the chosen tool |
| Why not ImGui for in-game UI? | Retained scenes need serialization, localization, draw batching — batcher path fits |

### Enabling ImGui in zGameLib

```sh
zig build -DimGui=true
zig build debug-ui -DimGui=true      # Nexus example (v0.8.0)
zig build crucible -DimGui=true      # Tier 3 — always on
```

When `-DimGui=false` (default), `@import("zimgui")` is a compile error — no silent stubs.

### In-game UI: 2D batcher path (not ImGui)

```zig
// Pseudocode — gameplay HUD via batcher (Tier 1 draw, Tier 2 policy)
fn drawHud(ctx: *NexusContext) void {
    const batch = ctx.rendering.begin2dBatch(ctx.active_viewport);
    defer ctx.rendering.end2dBatch(batch);

    // String resolved once — data-oriented lookup
    const play_label = ctx.localization.lookup(.{ .key = "UI_PLAY" });
    ctx.rendering.drawText(batch, play_label, .{ .x = 16, .y = 16 });

    ctx.rendering.drawSprite(batch, hud_atlas, play_button_frame, transform);
}
```

`Control` nodes (future) will cache layout + resolved string handles; hot paths batch draws
through `RenderingServer` without per-widget ImGui calls.

### Debug + editor frame integration (ImGui)

```zig
// Pseudocode — end of NexusApp.tick (Crucible or debug-ui)
if (app.config.enable_imgui) {
    zimgui.processPlatformEvents(&app.imgui, app.display);
    zimgui.newFrame(&app.imgui, .{ .dt = dt, .size = app.drawable_size });

    // Crucible: editor panels. Nexus debug-ui: stats only.
    app.tool_ui.draw(&app.imgui);

    try zimgui.render(&app.imgui, app.gpu.currentCmd(), app.render_pass);
}
```

Vulkan: ImGui pass uses **load-op LOAD** after scene render; same `FrameRing` slot.

### Usage matrix

| Use case | Owner | UI technology |
|----------|-------|---------------|
| Scene tree, inspector, gizmos | Crucible | Dear ImGui (required) |
| FPS / ECS sync overlay | Nexus `debug-ui` | Debug draw or optional ImGui |
| Menus, HUD, dialogue | Nexus `Control` + batcher | **No ImGui** |
| Headless CI | Nexus dummy backend | No UI |

---

## Part B — Localization (pointer)

Localization is **Nexus-only**, data-oriented, `.po` → JSON via **`build.zig`**, runtime
`LocalizationSystem` query API. Full design:

**→ [07 — LocalizationSystem](07-localization-system.md)** (build pipeline, ECS, engine comparisons)

---

## Tier boundary checklist

| Feature | zGameLib | Nexus | Crucible |
|---------|----------|-------|----------|
| 2D batcher / glyphs | ✅ planned | `RenderingServer` | — |
| `zimgui` | optional `-DimGui` | debug overlay only | **required** |
| `LocalizationSystem` | ❌ | ✅ query API | PO workflow + preview |
| PO → JSON in `build.zig` | ❌ | ✅ compile step | triggers rebuild |
| In-game `Control` UI | ❌ | ✅ batcher-backed | edits scene |

---

## Bibliography

- **Nexus Reference** — [`../Nexus_Reference.md`](../Nexus_Reference.md) §13–14
- **Roadmap** — [`../ROADMAP.md`](../ROADMAP.md) (v0.8.0, v1.1.0+, v1.2.0)
- **zGameLib ImGui** — [`../../zGameLib/docs/imgui.md`](../../zGameLib/docs/imgui.md)
- **debug-ui** — [`../examples/debug-ui.md`](../examples/debug-ui.md)
- **Localization** — [07](07-localization-system.md)
- **Resources** — [05](05-resource-and-asset-management.md)