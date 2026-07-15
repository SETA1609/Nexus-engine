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

## Part B — Data-oriented localization

### Why Nexus Engine, not zGameLib

| Concern | zGameLib | Nexus |
|---------|----------|-------|
| UTF-8 / file read | ✅ generic I/O | consumes |
| `.po` authoring | ❌ | ✅ `locale/src/` |
| `.po` → JSON compile | ❌ | ✅ `nexus-locale` build step |
| Runtime lookup tables | ❌ | ✅ `LocalizationSystem` |
| `tr()` in gameplay | ❌ | ✅ thin helper over lookup |

**Test:** Does a clear-color demo need locales? No → not Tier 1.

### Pipeline: `.po` for humans, JSON for the runtime

```ascii
AUTHORING                    BUILD                         RUNTIME (data-oriented)
─────────                    ─────                         ─────────────────────
locale/src/messages.pot      nexus-locale                  LocalizationSystem
locale/src/de/messages.po ─► res://locale/de.json    ─►   CompiledLocaleData (resource)
locale/src/en/messages.po    res://locale/en.json          flat entries + plural metadata
                                                           systems query by key — O(1)
```

| Stage | Format | Why |
|-------|--------|-----|
| **Source** | GNU `.po` | Poedit, Crowdin, `msgfmt`, `msgid_plural` — best translator tooling |
| **Shipped** | Compact **JSON** (optional `.nloc` binary later) | mmap-friendly; fixed schema; no gettext lexer in player |
| **Runtime** | **`LocalizationSystem`** + **`CompiledLocaleData`** | Data tables + query functions — not ICU / not i18next |

**Why not i18next JSON as source?** Web-centric nesting; weak CAT-tool support. We may *export*
i18next JSON; we do not author in it.

**Why not ICU?** Collation/calendars/break iterators are unrelated to game `tr()` lookup. Add
slim formatters in Nexus only when a server needs them.

### Data-oriented direction (API TBD at v1.2.0)

Localization is **state + tables**, not a deep object hierarchy. Gameplay systems, ECS phases,
and `Control` layout code will **query** compiled data. Exact types and function names are
**not frozen** in documentation — they will be specified when v1.2.0 implementation starts.

```ascii
NexusContext
  └── localization: LocalizationSystem
        ├── active_locale: LocaleId
        ├── fallback_chain: []LocaleId
        └── tables: []CompiledLocaleData    // loaded resources, refcounted

CompiledLocaleData (resource)
  ├── locale: "de"
  ├── plural_rule: baked from PO header
  └── entries: flat array { key, ctxt?, singular, plurals[] }
```

**Design intent (illustrative):**

```zig
// Shapes TBD — illustrates query model only
const play = ctx.localization.resolve("UI_PLAY") orelse "UI_PLAY";
```

- **ECS** — resolve on locale change, not per frame.
- **Build** — `nexus-locale` validates `.po`, emits JSON under `res://locale/`.
- **Sugar** — Godot-style `tr()` helpers likely; names frozen at implementation.

**Example compiled JSON:**

```json
{
  "version": 1,
  "locale": "de",
  "plural_rule": "nplurals=2; plural=(n != 1);",
  "entries": [
    { "key": "UI_PLAY", "s": "Spielen" },
    { "key": "ITEM_COUNT", "p": ["%d Gegenstand", "%d Gegenstände"] }
  ]
}
```

---

## Part C — Comparison with other engines

### Godot / Redot (integrated)

| Aspect | Godot / Redot | Nexus |
|--------|---------------|-------|
| Editor UI | Custom retained toolkit in-engine | Dear ImGui in **detachable** Crucible |
| Game UI | `Control` node tree | `Control` + **2D batcher** (same goal, explicit draw path) |
| i18n API | `TranslationServer` singleton | `LocalizationSystem` (API TBD) + familiar `tr()` sugar |
| i18n source | CSV/PO often loaded at runtime | `.po` → compile → JSON only at runtime |
| Foundation | Monolithic engine binary | zGameLib unaware of locales |

**Learn from Godot:** `tr()` ergonomics and locale fallback chain — keep the developer experience.  
**Avoid:** parsing translation formats in shipping players; editor+runtime UI in one distribution.

### Unity (data-driven localization)

| Aspect | Unity | Nexus |
|--------|-------|-------|
| Authoring | Localization tables / string collections as **assets** | `.po` files (vendor-friendly) |
| Runtime | `LocalizedString` references table entries | `CompiledLocaleData` + key lookup |
| Build | Asset bundles include string tables | `nexus-locale` emits `res://locale/*.json` |

**Learn from Unity:** treat strings as **data assets** referenced by key, not scattered literals.  
**Our twist:** PO source for translators; compiled flat tables for fast cold start.

### Unreal (build-time processing)

| Aspect | Unreal | Nexus |
|--------|--------|-------|
| Source | `LOCTEXT` namespaces + gather | `.po` + optional `xgettext` later |
| Pipeline | Gather → compile → staged `.locres` | `nexus-locale` → JSON (or `.nloc`) |
| Runtime | `FText` / `NSLOCTEXT` lookup | `LocalizationSystem.lookup` — explicit, no `FText` stack |

**Learn from Unreal:** **compile before ship** — never parse authoring formats in the player.  
**Our twist:** smaller runtime — JSON/hash lookup without full `FText` internationalization.

### Bevy / modern ECS engines

| Aspect | Bevy (ecosystem) | Nexus hybrid |
|--------|------------------|--------------|
| i18n | Community crates (`bevy_localization`, asset-based JSON) | First-party `LocalizationSystem` in Tier 2 |
| UI | `bevy_ui` retained nodes | SceneNode `Control` + batcher |
| Data orientation | Components + asset loaders | ECS queries + compiled locale resources |

**Learn from Bevy:** loaders produce **assets**; systems read immutable data per locale.  
**Our twist:** retained SceneNode authoring + optional ECS mirror — localization sits beside
`ResourceDB`, queryable from both node and system code.

### Summary trade-offs

| We gain | We give up |
|---------|------------|
| Modular tiers; no ImGui in player builds | No single all-in-one SDK download |
| Fast runtime (compiled JSON, flat lookup) | Explicit compile step on export |
| Professional PO translator workflow | No runtime CSV/PO hot-load in v1.2.0 |
| Headless tests of `LocalizationSystem` | Godot-style "drop CSV in res://" magic |
| Immediate-mode editor velocity (ImGui) | Custom Godot-style editor widget library |

---

## Tier boundary checklist

| Feature | zGameLib | Nexus | Crucible |
|---------|----------|-------|----------|
| 2D batcher / glyphs | ✅ planned | `RenderingServer` | — |
| `zimgui` | optional `-DimGui` | debug overlay only | **required** |
| `LocalizationSystem` | ❌ | ✅ query API | PO workflow + preview |
| `nexus-locale` | ❌ | ✅ build step | triggers compile |
| In-game `Control` UI | ❌ | ✅ batcher-backed | edits scene |

---

## Bibliography

- **Nexus Reference** — [`../Nexus_Reference.md`](../Nexus_Reference.md) §13–14
- **Roadmap** — [`../ROADMAP.md`](../ROADMAP.md) (v0.8.0, v1.1.0+, v1.2.0)
- **zGameLib ImGui** — [`../../zGameLib/docs/imgui.md`](../../zGameLib/docs/imgui.md)
- **debug-ui** — [`../examples/debug-ui.md`](../examples/debug-ui.md)
- **Resources** — [05](05-resource-and-asset-management.md)