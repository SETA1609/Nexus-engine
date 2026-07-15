# Nexus — Architecture Overview

> **Official name:** **Nexus** (repository: `Nexus-engine`, Tier 2).  
> **Aliases:** *Forge* (engine runtime) · *Crucible* (editor, Tier 3).  
> **Full reference:** [`Nexus_Reference.md`](Nexus_Reference.md) · **Theory:** [`theory/README.md`](theory/README.md)

Nexus is a **hybrid game engine** on **zGameLib** (Tier 1) — clean-room modernization
inspired by Redot/Godot *behavior*, not code. Development is **incremental and
example-driven**: each version ships at least one proving example (see [`ROADMAP.md`](ROADMAP.md)).

---

## 3-tier stack

```ascii
┌──────────────────────────────────────────────────────────────┐
│  TIER 3: CRUCIBLE (Editor)                                   │
│    Opinionated immediate-mode UI (Dear ImGui)                │
│    Docs in this repo (docs/crucible/) — separate repo later  │
└───────────────────────────────┬──────────────────────────────┘
                                │ EditorHost
┌───────────────────────────────▼──────────────────────────────┐
│  TIER 2: NEXUS (this repo)                                   │
│    SceneNode tree + optional ECS (Flecs adapter first)       │
│    Servers · resources · LocalizationSystem (high-level)     │
└───────────────────────────────┬──────────────────────────────┘
                                │ zgame.*
┌───────────────────────────────▼──────────────────────────────┐
│  TIER 1: zGAMELIB — lean foundation                        │
│    platform · Vulkan · FrameRing · (later) batcher, ImGui    │
└──────────────────────────────────────────────────────────────┘
```

Nexus is **just another consumer** of zGameLib — game code can always reach `zgame.*` directly.

---

## Finalized decisions (summary)

| Topic | Decision |
|-------|----------|
| **Naming** | Engine = **Nexus**; repo = `Nexus-engine`; editor = **Crucible** |
| **ECS** | **Flecs adapter** first (`nexus.ecs.flecs`); native Zig ECS evaluated later only if needed |
| **UI** | **Opinionated immediate mode** for tools (Casey Muratori style); **semi-retained only when necessary** (scene `Control` nodes for serialization); in-game draw via zGameLib **2D batcher** |
| **ImGui** | Optional in zGameLib — **toward the end** of Tier 1 roadmap; **required** in Crucible when editor ships |
| **Examples** | Every version ≥0.1.0 ships **implementation + docs + proving example** |
| **Localization** | Nexus-only; `.po` → **`build.zig`** → JSON; `LocalizationSystem` query API ([07](theory/07-localization-system.md)) |
| **zGameLib scope** | Minimal core; optional modules (ImGui, **fonts after ImGui**) land late |
| **Crucible** | Documentation in **this repository** for now; optional separate repo later |

---

## Hybrid scene + ECS

```ascii
Authoring (always)                 Performance (opt-in)
──────────────────                 ────────────────────
SceneTree / SceneNode              Flecs world (adapter)
  Player · Sprite · Camera            e_player · e_sprite …
         │                                   ▲
         └────────── EcsBridge ──────────────┘
```

- **SceneNodes** — gameplay API, serialization, Crucible editing, Godot-like ergonomics.
- **ECS** — hot paths (physics, particles, render gather); **Flecs first**, swappable adapter.
- **Never** — replace the SceneNode tree with pure ECS for authoring.

See [`theory/01-scene-representation.md`](theory/01-scene-representation.md),
[`theory/02-ecs-integration.md`](theory/02-ecs-integration.md).

---

## UI philosophy

```ascii
IMMEDIATE MODE (default for tools)     SEMI-RETAINED (only when necessary)
──────────────────────────────────     ────────────────────────────────────
Crucible: Dear ImGui                   Control nodes in scene tree
Debug: optional ImGui or debug draw    Serialization + localized HUD
                                       Drawn via 2D batcher — NOT ImGui
```

**Rule:** Prefer immediate mode. Add retained scene UI only where persistence, layout, or
localization in scene files genuinely helps — not as a default widget toolkit.

---

## Localization (high level)

- **Tier:** Nexus only — not zGameLib.
- **Authoring:** translators edit `.po` files.
- **Build:** PO → JSON inside **`build.zig`** (`build/compile_locale.zig`).
- **Runtime:** `LocalizationSystem` — `lookup`, pluralization, `tr()` sugar; ECS resolve on locale change.
- **Detail:** [`theory/07-localization-system.md`](theory/07-localization-system.md).

---

## Comparison with other engines (at a glance)

| | Godot / Redot | Unity | Unreal | Bevy | **Nexus** |
|--|---------------|-------|--------|------|-----------|
| **Editor** | Built-in, custom UI | External editors | Unreal Editor | Ecosystem | **Crucible** (ImGui, detachable) |
| **Game structure** | SceneNode tree | GameObjects | Actors/Components | ECS-first | **SceneNode + optional ECS** |
| **ECS** | Optional (not core) | DOTS optional | Mass optional | Core | **Flecs adapter, opt-in** |
| **Tool UI model** | Retained editor widgets | IMGUI / UIToolkit | Slate | varies | **Immediate mode (ImGui)** |
| **Game UI** | Control nodes | uGUI / UI Toolkit | UMG | bevy_ui | **Batcher + semi-retained Controls** |
| **i18n** | TranslationServer runtime | Localization tables | LOCTEXT → compile | community crates | **Compile-first, Nexus-only** |
| **Foundation** | Monolithic engine | Unity runtime | Unreal modules | bevy crates | **zGameLib — minimal, optional modules late** |

**What we learn:** Godot scene ergonomics; Unity/Unreal compile-before-ship strings; Bevy data-oriented assets.  
**What we avoid:** monolithic editor+runtime; ICU-weight i18n; forcing ImGui on shipped game UI.

---

## Design principles

| Principle | Nexus |
|-----------|-------|
| Raw-first | `zgame` reachable from game code |
| Servers over monoliths | Swappable backends + dummy servers |
| Explicit | Vulkan-only graphics |
| Hybrid by default | Nodes for UX; ECS where profiling demands |
| Example-driven | Each release proves one new capability |
| Clean-room | Redot informs behavior; no Godot/Redot source |

---

## Dependency graph

```ascii
Nexus (Tier 2)
  SceneTree · EcsBridge (Flecs) · ResourceDB · NexusApp
  RenderingServer · PhysicsServer · LocalizationSystem (v1.2.0)
        │
zGameLib (Tier 1)
  platform · Gpu · FrameRing · zclip
  (planned, late) 2D batcher → zimgui → fonts
```

| | Nexus (`Nexus-engine`) | zGameLib |
|--|--|--|
| Layout | [`file-tree.yml`](file-tree.yml) | [`../zGameLib/docs/file-tree.yml`](../zGameLib/docs/file-tree.yml) |
| Dependencies | [`dependencies.yml`](dependencies.yml) | [`../zGameLib/docs/dependencies.yml`](../zGameLib/docs/dependencies.yml) |

---

## macOS

**In scope.** CI = `zig build` on macOS VMs; contributors validate windowed examples on real
hardware. [`ROADMAP.md` § macOS](ROADMAP.md#macos-platform-policy).

---

## Current state & next releases

Bootstrap today — docs ahead of code (`src/main.zig` = zGameLib window loop).

| Version | Example | Proves |
|---------|---------|--------|
| **0.1.0** | `clear-color` | `NexusApp` + `RenderingServer` |
| **0.2.0** | `textured-quad`, `node-hierarchy` | SceneNode tree |
| **0.3.0–0.4.0** | `ecs-basic`, `hybrid-sync` | Flecs adapter + bridge |
| **1.0.0** | `minimal-game` | Shippable game without editor |
| **1.1.0+** | Crucible (docs in-repo) | Editor via `EditorHost` |
| **1.2.0** | i18n (TBD example) | Localization pipeline |

Example ladder: [`examples/ladder.md`](examples/ladder.md) · Crucible docs: [`crucible/README.md`](crucible/README.md).