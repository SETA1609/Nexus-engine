# 07 — LocalizationSystem: data-oriented strings and build.zig pipeline

*How Nexus compiles translator `.po` files at build time, loads JSON at runtime, and exposes a
lightweight query API for ECS systems — without Godot's monolithic `TranslationServer`.*

> **Release alignment:** **v1.2.0** · Prerequisite: [05](05-resource-and-asset-management.md)
> (`ResourceDB`) · UI context: [06](06-ui-and-localization.md) (tier boundaries only).

---

## Problem statement

Games need translated strings with plural forms. Translators need professional tooling. The
runtime needs **fast, explicit lookups** that ECS systems can call without dragging in ICU,
gettext parsers, or editor code.

**Nexus decision:** localization is **Tier 2 only** — not zGameLib, not Crucible runtime logic.

```ascii
TRANSLATORS          BUILD (build.zig)              RUNTIME (Nexus)
───────────          ─────────────────              ───────────────
.po files      ──►   po → JSON compile step   ──►  LocalizationSystem
(CAT tools)          integrated in zig build         query by key / plural
```

---

## Why not Godot's TranslationServer?

Godot's [`TranslationServer`](https://docs.godotengine.org/en/stable/classes/class_translationserver.html)
is a convenient **engine singleton** that loads CSV/PO at runtime, merges locales, and powers
`tr()` across GDScript and the editor. It works — but it is **monolithic**:

| Godot `TranslationServer` | Nexus `LocalizationSystem` |
|---------------------------|----------------------------|
| Lives inside the engine core | Lives in Nexus `nexus.i18n` only |
| Parses translation formats in the **player** | Player loads **pre-compiled JSON** only |
| Editor + runtime share one service | Crucible edits `.po`; runtime queries tables |
| Implicit global singleton | Explicit field on `NexusContext` |
| Hard to test without engine boot | Unit-test lookup + compile step in isolation |

We keep Godot-familiar **`tr()` / locale fallback** ergonomics. We drop runtime format parsing
and tight editor coupling.

**Further reading:** [Godot — Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html)

---

## Comparison with Unity and Unreal

### Unity Localization package

Unity's [Localization package](https://docs.unity3d.com/Packages/com.unity.localization@1.0/manual/index.html)
treats strings as **data assets**: `String Table` collections, `LocalizedString` references,
and locale selectors drive runtime resolution. Build pipelines bundle tables into player content.

| Unity | Nexus |
|-------|-------|
| String Table assets | `CompiledLocaleData` JSON resources |
| `LocalizedString` asset refs | Key strings + optional interned `StringKey` |
| Package-driven workflow | **`build.zig` compile step** + `res://locale/` |

**Learn:** keys reference data, not scattered literals.  
**Our twist:** [GNU `.po`](https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html) as
the translator source format (better CAT-tool support than nested JSON).

### Unreal Engine localization

Unreal gathers `LOCTEXT` / `NSLOCTEXT` macros, compiles [`FText`](https://docs.unrealengine.com/en-US/API/Runtime/Core/Internationalization/FText/)
data into staged `.locres` files, and resolves at runtime through its localization pipeline.
See [Unreal — Localization](https://docs.unrealengine.com/en-US/ProductionPipelines/Localization/LocalizationOverview/).

| Unreal | Nexus |
|--------|-------|
| Gather → compile → `.locres` | `build.zig` → `res://locale/*.json` |
| `FText` stack (namespaces, history) | Flat `lookup(key)` — explicit, small |
| Build tool chain (UAT, etc.) | Single-repo **`zig build`** integration |

**Learn:** **compile before ship** — never parse authoring formats in the player.  
**Our twist:** no `FText` weight; JSON + hash map is enough for game `tr()` needs.

### Bevy (ECS ecosystem)

Community crates (e.g. asset-based JSON loaders) follow the same pattern: **immutable locale
assets** loaded once, read by systems. Nexus makes this first-party beside `ResourceDB`, callable
from both ECS phases and `SceneNode` `Control` code.

---

## Build-time pipeline (`build.zig`)

The `.po` → JSON conversion runs **inside `build.zig`** — not a separate manual tool users
must remember to invoke. This matches modern Zig projects: one build graph, reproducible outputs,
CI-friendly.

```ascii
locale/src/
  messages.pot
  de/messages.po
  en/messages.po
        │
        ▼
build.zig  ──►  CompileLocaleStep (per .po or batch)
        │         • parse PO (build-time only)
        │         • validate msgid / plural forms
        │         • emit JSON schema v1
        ▼
zig-out/locale/          (or copied into res:// for examples)
  de.json
  en.json
        │
        ▼
ResourceLoader at runtime  ──►  CompiledLocaleData resource
```

### `build.zig` integration (pseudocode)

```zig
// build.zig — illustrative; lands with v1.2.0
const compile_locale = @import("build/compile_locale.zig");

pub fn build(b: *std.Build) void {
    const nexus = b.addModule("nexus", .{ .root_source_file = … });

    // Locale compile — runs before tests/examples that need strings
    const locale_out = b.pathJoin(&.{ b.install_path, "locale" });
    const compile_step = compile_locale.addPoToJsonStep(b, .{
        .po_root = "locale/src",
        .output_dir = locale_out,
    });

    const exe = b.addExecutable(.{ … });
    exe.step.dependOn(compile_step); // examples embed or load zig-out/locale

    // Optional: watch .po in dev — rebuild JSON when translators save
    compile_step.setDirtyTracking(.{ .files = &.{ "locale/src" } });
}
```

**Design rules**

| Rule | Rationale |
|------|-----------|
| Compile in `build.zig` | Same command as `zig build` / `zig build test` — no drift |
| No PO parser in player | Smaller binary; faster cold start |
| Fail build on invalid PO | Catch translator mistakes in CI |
| Versioned JSON schema | `version: 1` field allows future migration |

### Compiled JSON schema (v1)

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

| Field | Source in `.po` |
|-------|------------------|
| `key` | `msgid` |
| `s` | singular `msgstr` |
| `p` | `msgid_plural` → `msgstr[n]` forms |
| `plural_rule` | `Plural-Forms` header |

Optional later: `ctxt` for disambiguation (`msgctxt`).

---

## Runtime: `LocalizationSystem`

A **lightweight, query-based** service on `NexusContext`. It owns active locale state and
handles to loaded `CompiledLocaleData` resources — not a deep OO hierarchy.

```ascii
NexusContext
  └── localization: LocalizationSystem
        ├── active: LocaleTag          // e.g. "de"
        ├── fallbacks: []LocaleTag     // from project.nexus
        └── tables: map(LocaleTag → *CompiledLocaleData)
```

### Core API (v1.2.0 contract)

```zig
// nexus/i18n/localization_system.zig — pseudocode
pub const LocalizationSystem = struct {
    active: LocaleTag,
    fallbacks: []const LocaleTag,
    tables: std.StringArrayHashMap(*CompiledLocaleData),

    /// Primary query — O(1) average after load
    pub fn lookup(self: *const LocalizationSystem, key: []const u8) ?[]const u8 {
        return self.lookupIn(self.active, key) orelse self.lookupFallbacks(key);
    }

    /// Plural — index baked from PO Plural-Forms at compile time
    pub fn lookupPlural(self: *const LocalizationSystem, key: []const u8, n: i32) ?[]const u8 {
        const data = self.tables.get(self.active) orelse return null;
        const entry = data.find(key) orelse return null;
        const idx = data.plural_rule.select(n);
        return entry.pluralForms()[idx];
    }

    pub fn setLocale(self: *LocalizationSystem, tag: LocaleTag) !void {
        try self.ensureLoaded(tag);
        self.active = tag;
    }
};

// Thin sugar — Godot-familiar
pub fn tr(ctx: *NexusContext, key: []const u8) []const u8 {
    return ctx.localization.lookup(key) orelse key;
}

pub fn tr_n(ctx: *NexusContext, key: []const u8, n: i32) []const u8 {
    return ctx.localization.lookupPlural(key, n) orelse key;
}
```

**Properties**

| Property | Behavior |
|----------|----------|
| Missing key | Returns key string in dev; optional warning log |
| Fallback chain | Walk `project.nexus` fallbacks (e.g. `de` → `en`) |
| Threading | Read-only queries after load; locale switch on main thread |
| No ICU | Plural index from compiled rule; no collation/calendars in v1.2.0 |

---

## ECS integration

Localization is **data-oriented** — systems query or consume pre-resolved handles, not virtual
methods on a global singleton.

```ascii
Locale change event
        │
        ▼
resolve_localized_strings system   (runs once per locale change)
        │
        ▼
LocalizedText component { handle: StringHandle }   on UI entities
        │
        ▼
render_ui_system reads handle → draw via RenderingServer
```

```zig
// Pseudocode — ECS path
pub const LocalizedText = struct { key: []const u8, resolved: ?[]const u8 };

fn resolveLocalizedSystem(world: *World, loc: *LocalizationSystem) void {
    var q = world.query(.{ LocalizedText });
    while (q.next()) |entity| {
        entity.localized_text.resolved = loc.lookup(entity.localized_text.key);
    }
}

// Hot path — no tr() per frame
fn drawHudSystem(q: Query(LocalizedText, …)) void {
    for (q) |item| {
        drawText(item.localized_text.resolved orelse item.localized_text.key);
    }
}
```

**Rule:** resolve on **locale change**, not every frame. Particle sims and physics never touch
`LocalizationSystem` unless they display dynamic counted strings (`tr_n` at event time is fine).

---

## Project layout

```ascii
Nexus-engine/
  locale/src/           # VCS — translators commit .po here
    messages.pot
    de/messages.po
    en/messages.po
  build/
    compile_locale.zig  # PO → JSON (invoked from build.zig)
  src/nexus/i18n/
    localization_system.zig
    compiled_locale_data.zig
  zig-out/locale/       # build output (dev); packaged to res:// on export
```

`project.nexus` (v1.2.0):

```toml
# illustrative
locale = "en"
locale_fallbacks = ["en"]
```

---

## Tier boundaries

| Concern | zGameLib | Nexus | Crucible |
|---------|----------|-------|----------|
| Read UTF-8 bytes | ✅ | consumes | — |
| PO → JSON compile | ❌ | ✅ `build.zig` | triggers rebuild |
| `LocalizationSystem` | ❌ | ✅ | — |
| Edit `.po` files | ❌ | — | ✅ workflow UI |
| Preview locale | ❌ | play mode | ✅ |

---

## Testing strategy

| Test | Layer |
|------|-------|
| PO parse + JSON snapshot | `zig build test` — compile_locale unit tests |
| Lookup + plural index | `LocalizationSystem` tests — no GPU |
| Fallback chain | contract tests with fixture JSON |
| End-to-end | v1.2.0 example (`i18n-demo` or locale switch in `minimal-game`) |

---

## Summary

| Question | Answer |
|----------|--------|
| Where does i18n live? | Nexus Tier 2 only |
| Translator format? | `.po` in `locale/src/` |
| When is JSON produced? | **`zig build`** via `build.zig` step |
| Runtime API? | `LocalizationSystem.lookup` / `lookupPlural`; `tr()` sugar |
| ECS? | Resolve on locale change; hot paths read handles |
| vs Godot? | Same `tr()` UX; no runtime PO parse; no monolithic server |
| vs Unity/Unreal? | Data assets + compile-before-ship; smaller runtime than `FText` |

---

## Bibliography

- **Nexus Reference** — [`../Nexus_Reference.md`](../Nexus_Reference.md) §14
- **Resources** — [05](05-resource-and-asset-management.md)
- **Roadmap** — [`../ROADMAP.md`](../ROADMAP.md) v1.2.0
- [Godot TranslationServer](https://docs.godotengine.org/en/stable/classes/class_translationserver.html)
- [Godot — Internationalizing games](https://docs.godotengine.org/en/stable/tutorials/i18n/internationalizing_games.html)
- [Unity Localization package](https://docs.unity3d.com/Packages/com.unity.localization@1.0/manual/index.html)
- [Unreal — Localization overview](https://docs.unrealengine.com/en-US/ProductionPipelines/Localization/LocalizationOverview/)
- [GNU gettext — PO files](https://www.gnu.org/software/gettext/manual/html_node/PO-Files.html)