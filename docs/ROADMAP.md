# Nexus-engine Roadmap

**Goal:** Build a modern, hybrid game engine (Tier 2) on top of zGameLib — retained
`SceneNode` hierarchy for authoring, optional ECS for hot paths, Vulkan-only rendering,
clean-room modernization inspired by Redot/Godot behavior (not code).

**Aliases:** Nexus Engine = *Forge* · Link-editor = *Crucible*

| Doc | Purpose |
|-----|---------|
| [`Nexus_Reference.md`](Nexus_Reference.md) | Authoritative API + hybrid architecture |
| [`theory/README.md`](theory/README.md) | Why the engine is shaped this way (read 01→06) |
| [`examples/ladder.md`](examples/ladder.md) | Per-example design + build targets |
| [`file-tree.yml`](file-tree.yml) · [`dependencies.yml`](dependencies.yml) | Repo layout and Tier 1 deps |
| [zGameLib ROADMAP](../zGameLib/docs/ROADMAP.md) | Tier 1 foundation milestones |

> **Philosophy (via zGameLib / Handmade Hero):** thin layers, explicit control,
> replaceable pieces, raw `zgame.*` always reachable, no framework magic.

**Current release line:** `0.0.x` — documentation ahead of implementation (July 2026).

---

## Hybrid architecture (one diagram)

```ascii
Authoring surface (always)          Performance plane (opt-in)
─────────────────────────          ────────────────────────────
SceneTree / SceneNode              ECS world (Flecs → maybe native Zig)
  Player · Sprite · Camera             e_player · e_sprite · …
         │                                    ▲
         └────────── EcsBridge ──────────────┘
                         │
              NexusApp.tick() ──► Servers ──► zGameLib (Tier 1)
```

- **SceneNodes** — serialization, editor (Crucible), gameplay API, hierarchy.
- **ECS** — physics integration, render gather, particles, crowds (opt-in per node).
- **Crucible (Tier 3)** — detachable editor; immediate-mode Dear ImGui (`-DimGui`); in-game UI stays on 2D batcher.

---

## Version milestones

Each release ships **implementation + documentation + at least one example**
(unless noted). Examples are **reference apps** — `zig build <name>` — not embedded
in the `nexus-engine` artifact. Design docs: [`docs/examples/`](examples/).

| Version | Codename | Example(s) | What users can do after this release |
|---------|----------|------------|--------------------------------------|
| **0.0.1** | *Bootstrap* | — (internal) | Repo builds; `nexus` module exists; contract tests gate CI |
| **0.1.0** | *Window* | [`clear-color`](examples/clear-color.md) | Run engine loop; clear-color through `NexusApp` + `RenderingServer` |
| **0.2.0** | *Nodes* | [`textured-quad`](examples/textured-quad.md), [`node-hierarchy`](examples/node-hierarchy.md) | Build scenes in code; parent/child nodes; draw textured quad |
| **0.3.0** | *ECS seed* | [`ecs-basic`](examples/ecs-basic.md) | Opt-in ECS mirror on nodes; Flecs entity lifecycle |
| **0.4.0** | *Bridge* | [`hybrid-sync`](examples/hybrid-sync.md) | Node ↔ ECS transform sync; understand hybrid authority |
| **0.5.0** | *Input* | [`simple-movement`](examples/simple-movement.md) | `InputMap` actions; move nodes in `process` |
| **0.6.0** | *View* | [`camera`](examples/camera.md) | `Camera2D` / basic `Camera3D`; viewport routing |
| **0.7.0** | *Heat* | [`particles`](examples/particles.md) | ECS-only entities (no `SceneNode` per particle) |
| **0.8.0** | *Debug* | [`debug-ui`](examples/debug-ui.md) | In-engine stats overlay (not Crucible) |
| **0.9.0** | *World* | [`physics-ball`](examples/physics-ball.md) | `PhysicsServer` + bridge; fixed timestep |
| **1.0.0** | *Alpha* | [`minimal-game`](examples/minimal-game.md) | Ship a small game without editor; `EditorHost` v1 frozen |
| **1.1.0+** | *Crucible* | (Tier 3 repo) | Detachable editor; play mode; inspectors |
| **1.2.0** | *i18n* | — | `LocalizationSystem`, `.po`→JSON compile, `tr()` / `tr_n()` |

---

## Per-version detail

### v0.0.1 — Bootstrap *(in progress)*

**Implementation**

- [ ] `src/nexus/` module + `build.zig` exports `nexus`
- [ ] `NexusApp` / `NexusContext` stubs; `main.zig` delegates to app
- [ ] `zig build test` contract suite (compile-only API checks)
- [ ] `RenderingServer` dummy backend for headless CI
- [ ] Legal scaffold: `LICENSE`, `NOTICE`, `CONTRIBUTING.md`

**Documentation**

- [x] Theory ladder 00–06, `Nexus_Reference.md`, architecture overview
- [x] Versioned roadmap + example ladder (this file)
- [ ] `getting-started.md` — bootstrap build instructions

**Example:** none (CI proves `zig build` only).

---

### v0.1.0 — Window + clear-color

**Implementation**

- [ ] `NexusApp.init` / `tick` / `deinit` — owns window via zGameLib
- [ ] `RenderingServer` over `Gpu` + `FrameRing` (live + dummy)
- [ ] Empty `SceneTree` root (no drawable nodes yet)
- [ ] Fixed/variable timestep accumulator (empty physics step OK)

**Documentation**

- [ ] `Nexus_Reference.md` §4.1 runtime — mark **shipped** APIs
- [ ] [`examples/clear-color.md`](examples/clear-color.md) — frame loop walkthrough
- [ ] Theory [03](theory/03-systems-and-update-loop.md) — phases 1 + 6 only

**Example:** `clear-color` — proves Tier 2 owns the loop, not raw `main.zig`.

**Tier 1 gate:** zGameLib `Gpu` + `FrameRing` (shipped).

---

### v0.2.0 — Scene nodes + textured quad

**Implementation**

- [ ] `SceneNode`, `SceneTree`, `Node2D`; `NodeId`, flags, deferred delete
- [ ] Hierarchical transforms (local → world); reparent
- [ ] `Sprite2D` or quad drawable; `ResourceDB` + texture load
- [ ] `RenderingServer` draws registered instances

**Documentation**

- [ ] Freeze SceneNode v1 in `Nexus_Reference.md` §5
- [ ] [`examples/textured-quad.md`](examples/textured-quad.md), [`examples/node-hierarchy.md`](examples/node-hierarchy.md)
- [ ] Theory [01](theory/01-scene-representation.md) — align pseudocode with shipped types
- [ ] Theory [05](theory/05-resource-and-asset-management.md) — minimal `ResourceDB`

**Examples**

- `textured-quad` — one drawable node, one texture.
- `node-hierarchy` — parent moves child; visibility/pause flags.

**Tier 1 gate:** image decode or minimal upload path (zGameLib `zassets` or interim loader).

---

### v0.3.0 — ECS basic

**Implementation**

- [ ] `nexus.ecs.flecs` — `World`, `Entity`, `Phase` (internal)
- [ ] `EcsBridge.attach` / `detach` on tree enter/exit
- [ ] `NodeId` ECS component; `ecs_mirrored` flag on `SceneNode`
- [ ] No transform sync yet — attach/detach only

**Documentation**

- [ ] `Nexus_Reference.md` §6 — Flecs adapter **partial**
- [ ] [`examples/ecs-basic.md`](examples/ecs-basic.md)
- [ ] Theory [02](theory/02-ecs-integration.md) — attach lifecycle, no sync policies yet

**Example:** `ecs-basic` — mirror two nodes; log entity ids; prove Flecs hidden from game code.

---

### v0.4.0 — Hybrid sync

**Implementation**

- [ ] Sync policies: `node_authoritative`, `ecs_authoritative`, `sim_only`
- [ ] `syncTransformsToNodes` / `syncTransformsToEcs`
- [ ] ECS `render_gather` stub; components `Transform`, `DrawInstance`
- [ ] Full `NexusApp.tick()` phases 1–5 per [theory/03](theory/03-systems-and-update-loop.md)

**Documentation**

- [ ] `Nexus_Reference.md` §6–7 — bridge + loop **shipped**
- [ ] [`examples/hybrid-sync.md`](examples/hybrid-sync.md)
- [ ] Theory [02](theory/02-ecs-integration.md) — complete sync section
- [ ] Theory [04](theory/04-performance-considerations.md) — when to mirror

**Example:** `hybrid-sync` — physics-style ECS write → node transform update on screen.

---

### v0.5.0 — Simple movement

**Implementation**

- [ ] `DisplayServer` input facade; `InputMap` (actions → keys/gamepad)
- [ ] `process` traversal reads actions
- [ ] Signals stub: `tree_entered` / `tree_exited`

**Documentation**

- [ ] `Nexus_Reference.md` — input + display servers
- [ ] [`examples/simple-movement.md`](examples/simple-movement.md)

**Example:** `simple-movement` — WASD moves a `Sprite2D`.

---

### v0.6.0 — Camera

**Implementation**

- [ ] `Camera2D` node; basic `Camera3D` smoke
- [ ] `RenderingServer` viewport / projection routing
- [ ] `Node3D` world matrix API (gizmo-ready for Crucible)

**Documentation**

- [ ] [`examples/camera.md`](examples/camera.md)
- [ ] Theory [01](theory/01-scene-representation.md) — spatial node types

**Example:** `camera` — follow sprite; split-screen optional stretch goal.

---

### v0.7.0 — Particles (ECS-only)

**Implementation**

- [ ] Spawner `SceneNode` + bulk ECS entities (no node per particle)
- [ ] Particle sim system in fixed/variable phases
- [ ] `RenderingServer` draws from ECS `DrawInstance` list

**Documentation**

- [ ] [`examples/particles.md`](examples/particles.md)
- [ ] Theory [04](theory/04-performance-considerations.md) — ECS-only pattern

**Example:** `particles` — 1k+ particles, one spawner node.

---

### v0.8.0 — Debug UI

**Implementation**

- [ ] Dev overlay: FPS, node count, ECS entity count, bridge sync ms
- [ ] Default path: `RenderingServer` debug text/quads (no ImGui required)
- [ ] Optional richer panels when consumer builds with zGameLib `-DimGui=true`

**Documentation**

- [ ] [`examples/debug-ui.md`](examples/debug-ui.md)
- [ ] [`theory/06-ui-and-localization.md`](theory/06-ui-and-localization.md) — ImGui tier split
- [ ] `Nexus_Reference.md` §13 — immediate mode UI strategy (optional ImGui)

**Example:** `debug-ui` — toggle overlay; proves profiling hooks.

```sh
zig build debug-ui                    # lightweight overlay
zig build debug-ui -DimGui=true       # optional ImGui panels (needs zGameLib zimgui)
```

**Note:** Full editor is **Crucible (Tier 3)** — not this release. ImGui is optional in
zGameLib and Nexus; **required** only in Crucible (v1.1.0+).

**Tier 1 gate:** zGameLib `zimgui` wrapper (`-DimGui`) — Q3 2026 Phase 1 (optional for v0.8).

---

### v0.9.0 — Physics

**Implementation**

- [ ] `PhysicsServer` + `DummyPhysicsServer`
- [ ] First backend (2D or Jolt 3D — pick when implementing)
- [ ] Fixed step + `physicsProcess`; bridge sync after sim

**Documentation**

- [ ] [`examples/physics-ball.md`](examples/physics-ball.md)
- [ ] Asset hot-reload skeleton (`ResourceReloaded` signal)

**Example:** `physics-ball` — drop/bounce; ECS + node transforms agree.

**Tier 1 gate:** stable fixed timestep + zGameLib maturity.

---

### v1.0.0 — Alpha

**Implementation**

- [ ] `EditorHost` API frozen (implementation still in engine; Crucible consumes it)
- [ ] `project.nexus` minimal settings
- [ ] Pooling + frame profiler defaults
- [ ] Evaluate `nexus.ecs.native` vs Flecs (spike only; no switch required)

**Documentation**

- [ ] Full theory ↔ API audit
- [ ] [`examples/minimal-game.md`](examples/minimal-game.md) — micro platformer or pong
- [ ] Example gallery index in [`examples/README.md`](examples/README.md)

**Example:** `minimal-game` — one small shippable game using only `nexus.*`.

---

### v1.1.0+ — Crucible (Tier 3, separate repo)

- Scene hierarchy dock, inspector, viewport gizmo
- Play / pause / step; scene snapshot on stop
- **Dear ImGui hard dependency** — immediate-mode tool UI (Casey Muratori style) via `zgame.zimgui`
- **Does not** link Flecs directly — uses `EditorHost.getEcsComponents`
- PO editing workflow in `locale/src/` — compile to JSON via `nexus-locale` (v1.2.0)

**Tier 1 gate:** zGameLib `zimgui` shipped and stable (Vulkan pass + SDL3 events).

---

### v1.2.0 — Localization

**Implementation**

- [ ] `LocalizationSystem` on `NexusContext` — data-oriented `lookup()` / `lookupPlural()`
- [ ] `CompiledLocaleData` resource — flat entries loaded from `res://locale/<lang>.json`
- [ ] `nexus-locale` build tool — `.po` in `locale/src/` → compiled JSON (optional `.nloc` later)
- [ ] Runtime loads **compiled data only** (no gettext parser, no ICU, no i18next)
- [ ] `tr()` / `tr_n()` sugar; ECS `StringKey` resolve on locale change
- [ ] `project.nexus` default locale + fallback list
- [ ] Crucible: PO edit/preview; triggers recompile (no i18n runtime in Tier 3)

**Documentation**

- [ ] `Nexus_Reference.md` §14 — mark **shipped**
- [ ] [`theory/06-ui-and-localization.md`](theory/06-ui-and-localization.md) — PO→JSON pipeline audit
- [ ] Theory [05](theory/05-resource-and-asset-management.md) — locale JSON as resources

**Example:** stretch — `minimal-game` locale switch (or dedicated `i18n-demo` if needed).

**Not in zGameLib:** no ICU, no i18next, no runtime `.po` parse — Tier 1 keeps UTF-8 I/O only.
**Deliberate choices:** `.po` for translator tooling; JSON for fast runtime; data-oriented `LocalizationSystem` vs ICU/i18next.

---

## Example ladder summary

```ascii
v0.1.0  clear-color        NexusApp owns the loop
v0.2.0  textured-quad      + drawable node
        node-hierarchy     + tree UX
v0.3.0  ecs-basic          + Flecs attach (no sync)
v0.4.0  hybrid-sync        + bridge sync
v0.5.0  simple-movement    + InputMap
v0.6.0  camera             + viewports
v0.7.0  particles          + ECS-only heat
v0.8.0  debug-ui           + dev overlay
v0.9.0  physics-ball       + PhysicsServer
v1.0.0  minimal-game       + alpha
v1.1.0+ Crucible           + editor (ImGui required)
v1.2.0  (i18n)             + LocalizationSystem (.po→JSON)
```

Build: `zig build <example>` · Design: [`docs/examples/<name>.md`](examples/)

---

## Development workflow

Same discipline as [zGameLib](../zGameLib/docs/ROADMAP.md):

1. **API first** — document in `Nexus_Reference.md`, then contract tests (`zig build test`).
2. **TDD** — red→green behavioral tests (`zig build test-tdd`) where display/GPU needed.
3. **Example proves integration** — each minor that adds user-visible capability ships an example doc + target.
4. **No GPL/LGPL/AGPL** — clean-room only.

---

## macOS platform policy

**In scope — not deferred.** Cocoa/Metal behavior follows Redot clean-room study;
CI runs `zig build` on macOS VMs; **contributors** validate windowed examples on real
hardware. Details: [zGameLib macOS policy](../zGameLib/docs/ROADMAP.md#macos-platform-policy).

---

## Tier 1 alignment

| Nexus version | Needs from zGameLib |
|---------------|---------------------|
| 0.1.0 | `Gpu`, `FrameRing` ✅ |
| 0.2.0 | Image decode / texture upload (Q3 2026 `zassets`) |
| 0.3.0–0.4.0 | Stable Vulkan pipelines |
| 0.5.0+ | Input depth (platform adapter) ✅ |
| 0.7.0 | 2D batcher or retained quad path |
| 0.9.0 | Optional: zaudio later for `AudioServer` |
| 0.8.0 debug-ui | `-DimGui` wrapper optional (Q3 2026 planned) |
| 1.1.0 Crucible | `-DimGui` wrapper **required** in Crucible build |
| 1.2.0 i18n | UTF-8 I/O via zGameLib; `.po` compile + JSON load entirely in Nexus |

---

## Long-term vision

| Pillar | Direction |
|--------|-----------|
| **Hybrid** | Nodes for authoring; ECS where profiling demands |
| **Separation** | zGameLib / Nexus / Crucible — three tiers, explicit boundaries |
| **UI** | ImGui for tools only (Crucible/debug); in-game HUD via 2D batcher |
| **i18n** | Data-oriented `LocalizationSystem`; `.po` → JSON compile; not in zGameLib |
| **Never** | Replace SceneNode tree with pure ECS |
| **ECS adapter** | Flecs first; optional native Zig ECS behind same interface |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Docs ahead of code | Version tags mark **shipped** vs **planned** in `Nexus_Reference.md` |
| zGameLib 2D batcher slips | Interim quad renderer in `RenderingServer` |
| Flecs ABI friction | Isolate in `nexus.ecs.flecs`; swappable adapter |
| Crucible scope creep | Tier 3 separate repo; `EditorHost` v1 frozen at 1.0.0 |