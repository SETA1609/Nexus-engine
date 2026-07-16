# Nexus Roadmap

**Official name:** **Nexus** (repository: `Nexus-engine`, Tier 2).

**Goal:** Build a modern, hybrid **2D-first** game engine on zGameLib — retained `SceneNode` hierarchy,
**Flecs adapter** for optional ECS hot paths, Vulkan-only rendering, data-driven content, WASM modding,
and example-driven releases. Ship a **complete 2D game at v1.0.0** before opening the 3D track (v2.x).

**Aliases:** *Forge* (runtime) · *Crucible* (editor, Tier 3)

| Doc | Purpose |
|-----|---------|
| [`Nexus_Reference.md`](Nexus_Reference.md) | Authoritative API + hybrid architecture |
| [`theory/README.md`](theory/README.md) | Why the engine is shaped this way (read 01→06) |
| [`examples/ladder.md`](examples/ladder.md) | Per-example design + build targets |
| [`file-tree.yml`](file-tree.yml) · [`dependencies.yml`](dependencies.yml) | Repo layout and Tier 1 deps |
| [`crucible/README.md`](crucible/README.md) | Crucible (Tier 3) editor — docs in-repo for now |
| [zGameLib ROADMAP](../libs/zGameLib/docs/ROADMAP.md) | Tier 1 foundation milestones |
| [Bundle ROADMAP](https://github.com/SETA1609/Link_and_nexus_bundle/blob/main/ROADMAP.md) | Cross-tier coordination (meta repo) |

> **Philosophy (via zGameLib / Handmade Hero):** thin layers, explicit control,
> replaceable pieces, raw `zgame.*` always reachable, no framework magic.

**Example-driven rule:** every version from **0.1.0** upward ships **implementation +
documentation + ≥1 proving example** (design doc in `docs/examples/`, target `zig build <name>`).

**Current release line:** `0.0.x` — documentation ahead of implementation (July 2026).

**Priority legend:** **🎯** first 2D game (through v1.0.0) · **🔧** editor tier (v1.1.0+) · **⏳** post–first 2D ship (v2.x)

---

## 2D-first strategy

| Principle | Detail |
|-----------|--------|
| **First ship** | v1.0.0 = `minimal-2d-game` — a complete 2D title without Crucible |
| **3D deferred** | `Node3D`, `Camera3D`, Jolt 3D, glTF — **v2.0.0+** only |
| **2D nodes first** | `Node2D`, `Sprite2D`, `Camera2D`, `TileMapLayer` (stretch at v1.0.0) |
| **2D physics** | `PhysicsServer2D` at v0.9.0 — not Jolt |
| **Data-driven** | Scene/resource format from v0.8.0; `project.nexus` at v1.0.0 |
| **Hot reload** | `ReloadEventBus` at v0.9.0; Crucible drives reload at v1.1.0+ |
| **WASM modding** | `WasmHost` + `ModManager` API at v1.0.0; Crucible build UI at v1.1.1 |
| **Networking** | GNS commitment — **⏳ v2.2.0** after 2D ship ([theory/11](theory/11-networking-decision.md)) |

---

## Hybrid architecture (one diagram)

```ascii
Authoring surface (always)          Performance plane (opt-in)
─────────────────────────          ────────────────────────────
SceneTree / SceneNode              ECS world (Flecs adapter → native Zig only if needed)
  Player · Sprite2D · Camera2D       e_player · e_sprite · …
         │                                    ▲
         └────────── EcsBridge ──────────────┘
                         │
              NexusApp.tick() ──► Servers ──► zGameLib (Tier 1)
```

- **SceneNodes** — serialization, editor (Crucible), gameplay API, hierarchy.
- **ECS** — Flecs adapter first; 2D physics, render gather, particles (opt-in per node).
- **UI** — immediate mode for tools; in-game HUD on **2D batcher** (not ImGui).
- **Crucible (Tier 3)** — separate repo; ImGui when zGameLib `zimgui` lands (late Tier 1).

---

## Version milestones

Each release ships **implementation + documentation + at least one example**
(unless noted). Examples are **reference apps** — `zig build <name>` — not embedded
in the `nexus-engine` artifact. Design docs: [`docs/examples/`](examples/).

| Version | Codename | Priority | Example(s) | What users can do after this release |
|---------|----------|----------|------------|--------------------------------------|
| **0.0.1** | *Bootstrap* | 🎯 | — (internal) | Repo builds; `nexus` module exists; contract tests gate CI |
| **0.1.0** | *Window* | 🎯 | [`clear-color`](examples/clear-color.md) | Run engine loop; clear-color through `NexusApp` + `RenderingServer` |
| **0.2.0** | *2D Nodes* | 🎯 | [`textured-quad`](examples/textured-quad.md), [`node-hierarchy`](examples/node-hierarchy.md) | `Node2D` / `Sprite2D`; parent/child; draw textured sprite |
| **0.3.0** | *ECS seed* | 🎯 | [`ecs-basic`](examples/ecs-basic.md) | Opt-in ECS mirror on nodes; Flecs entity lifecycle |
| **0.4.0** | *Bridge* | 🎯 | [`hybrid-sync`](examples/hybrid-sync.md) | Node ↔ ECS transform sync; hybrid authority |
| **0.5.0** | *Input* | 🎯 | [`simple-movement`](examples/simple-movement.md) | `InputMap` actions; move `Sprite2D` in `process` |
| **0.6.0** | *2D View* | 🎯 | [`camera`](examples/camera.md) | **`Camera2D` only**; orthographic viewport routing |
| **0.7.0** | *Heat* | 🎯 | [`particles`](examples/particles.md) | ECS-only 2D particles (no `SceneNode` per particle) |
| **0.8.0** | *Data* | 🎯 | [`debug-ui`](examples/debug-ui.md) | Dev overlay; **minimal scene/resource load from disk** |
| **0.9.0** | *2D Physics* | 🎯 | [`physics-ball`](examples/physics-ball.md) | **`PhysicsServer2D`** + bridge; `ReloadEventBus` hot reload |
| **1.0.0** | *2D Alpha* | 🎯 | [`minimal-2d-game`](examples/minimal-game.md) | **Ship first 2D game**; `EditorHost` v1 frozen; `WasmHost` stub |
| **1.1.0** | *Crucible* | 🔧 | editor smoke (Tier 3) | Detachable editor; 2D viewport; play mode |
| **1.1.1** | *Mods* | 🔧 | `mod-demo` (planned) | Load mods from disk; Crucible mod build UI |
| **1.2.0** | *i18n* | 🔧 | `i18n-demo` (planned) | `LocalizationSystem`; `.po`→JSON in `build.zig` |
| **2.0.0** | *3D Smoke* | ⏳ | `hello-3d` (planned) | `Node3D`, `Camera3D`; perspective viewport |
| **2.1.0** | *3D Content* | ⏳ | `gltf-scene` (planned) | glTF meshes; Jolt 3D backend |
| **2.2.0** | *Net* | ⏳ | `net-pong` (planned) | GNS `MultiplayerAPI` |

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

### v0.1.0 — Window + clear-color 🎯

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

### v0.2.0 — 2D scene nodes + textured sprite 🎯

**Implementation**

- [ ] `SceneNode`, `SceneTree`, **`Node2D`**; `NodeId`, flags, deferred delete
- [ ] Hierarchical 2D transforms (local → world); reparent
- [ ] **`Sprite2D`** drawable; `ResourceDB` + texture load
- [ ] `RenderingServer` draws registered 2D instances via batcher path

**Documentation**

- [ ] Freeze SceneNode v1 in `Nexus_Reference.md` §5
- [ ] [`examples/textured-quad.md`](examples/textured-quad.md), [`examples/node-hierarchy.md`](examples/node-hierarchy.md)
- [ ] Theory [01](theory/01-scene-representation.md) — align pseudocode with shipped types
- [ ] Theory [05](theory/05-resource-and-asset-management.md) — minimal `ResourceDB`

**Examples**

- `textured-quad` — one `Sprite2D`, one texture.
- `node-hierarchy` — parent moves child; visibility/pause flags.

**Tier 1 gate:** zGameLib image decode / texture upload (`zassets` or interim loader) + 2D batcher v0.

**Not in v0.2.0:** `Node3D`, mesh draw, depth buffer.

---

### v0.3.0 — ECS basic 🎯

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

### v0.4.0 — Hybrid sync 🎯

**Implementation**

- [ ] Sync policies: `node_authoritative`, `ecs_authoritative`, `sim_only`
- [ ] `syncTransformsToNodes` / `syncTransformsToEcs`
- [ ] ECS `render_gather` stub; components `Transform`, `DrawInstance` (2D)
- [ ] Full `NexusApp.tick()` phases 1–5 per [theory/03](theory/03-systems-and-update-loop.md)

**Documentation**

- [ ] `Nexus_Reference.md` §6–7 — bridge + loop **shipped**
- [ ] [`examples/hybrid-sync.md`](examples/hybrid-sync.md)
- [ ] Theory [02](theory/02-ecs-integration.md) — complete sync section
- [ ] Theory [04](theory/04-performance-considerations.md) — when to mirror

**Example:** `hybrid-sync` — ECS write → `Node2D` transform update on screen.

---

### v0.5.0 — Simple movement 🎯

**Implementation**

- [ ] `DisplayServer` input facade; `InputMap` (actions → keys/gamepad)
- [ ] `process` traversal reads actions
- [ ] Signals stub: `tree_entered` / `tree_exited`

**Documentation**

- [ ] `Nexus_Reference.md` — input + display servers
- [ ] [`examples/simple-movement.md`](examples/simple-movement.md)

**Example:** `simple-movement` — WASD moves a `Sprite2D`.

---

### v0.6.0 — Camera2D 🎯

**Implementation**

- [ ] **`Camera2D` node only** — zoom, offset, rotation (2D)
- [ ] `RenderingServer` orthographic viewport / projection routing
- [ ] Optional: camera follow helper on `Node2D`

**Documentation**

- [ ] [`examples/camera.md`](examples/camera.md) — update for 2D-only scope
- [ ] Theory [01](theory/01-scene-representation.md) — spatial node types (2D section)

**Example:** `camera` — follow sprite; split-screen optional stretch goal.

**Deferred to v2.0.0 ⏳:** `Camera3D`, `Node3D` world matrix, orbit controls.

---

### v0.7.0 — Particles (ECS-only, 2D) 🎯

**Implementation**

- [ ] Spawner `SceneNode` + bulk ECS entities (no node per particle)
- [ ] 2D particle sim system in fixed/variable phases
- [ ] `RenderingServer` draws from ECS `DrawInstance` list (sprites/quads)

**Documentation**

- [ ] [`examples/particles.md`](examples/particles.md)
- [ ] Theory [04](theory/04-performance-considerations.md) — ECS-only pattern

**Example:** `particles` — 1k+ 2D particles, one spawner node.

**Tier 1 gate:** zGameLib 2D batcher maturity.

---

### v0.8.0 — Debug UI + data-driven scenes 🎯

**Implementation**

- [ ] Dev overlay: FPS, node count, ECS entity count, bridge sync ms
- [ ] Default path: `RenderingServer` debug text/quads (**no ImGui required**)
- [ ] **Minimal scene format** — load `SceneTree` with `Node2D` / `Sprite2D` from disk
- [ ] **Resource paths** — `res://` URIs in scene files

**Documentation**

- [ ] [`examples/debug-ui.md`](examples/debug-ui.md)
- [ ] [`theory/06-ui-and-localization.md`](theory/06-ui-and-localization.md) — ImGui tier split
- [ ] `Nexus_Reference.md` §13 — immediate mode UI strategy (optional ImGui)
- [ ] Theory [05](theory/05-resource-and-asset-management.md) — scene serialization basics

**Example:** `debug-ui` — toggle overlay; load a scene file at startup.

```sh
zig build debug-ui                    # lightweight overlay
zig build debug-ui -DimGui=true       # optional ImGui panels (needs zGameLib zimgui)
```

**Note:** Full editor is **Crucible (Tier 3)** — not this release.

---

### v0.9.0 — 2D physics + hot reload 🎯

**Implementation**

- [ ] **`PhysicsServer2D`** + `DummyPhysicsServer2D`
- [ ] First 2D backend (Box2D-style or custom — pick when implementing)
- [ ] Fixed step + `physicsProcess`; bridge sync after sim
- [ ] **`ReloadEventBus`** — file watcher stub; `ResourceDB.invalidate` → re-upload
- [ ] `ResourceReloaded` signal

**Documentation**

- [ ] [`examples/physics-ball.md`](examples/physics-ball.md) — 2D bounce demo
- [ ] [`theory/08-hot-reload-nexus-engine.md`](theory/08-hot-reload-nexus-engine.md) — resource reload

**Example:** `physics-ball` — 2D drop/bounce; ECS + node transforms agree; edit texture on disk → hot reload.

**Deferred to v2.1.0 ⏳:** Jolt 3D backend.

**Tier 1 gate:** stable fixed timestep + zGameLib maturity.

---

### v1.0.0 — First 2D game (Alpha) 🎯

**Goal:** Ship a **complete 2D game** — platformer, top-down adventure, or pong-plus — using only `nexus.*` public APIs. No Crucible required.

**Implementation**

- [ ] **`EditorHost` API frozen** (implementation in engine; Crucible consumes it)
- [ ] **`project.nexus`** — display, input, physics, mod paths
- [ ] **`WasmHost` + `ModManager`** — load `mod.json` + optional `mod.wasm` from `mods/`
- [ ] Mod API v1: `log`, `spawn`, `get_node`, `on_tick` ([theory/13](theory/13-wasm-modding.md))
- [ ] Pooling + frame profiler defaults
- [ ] Stretch: **`TileMapLayer`** for tile-based 2D levels
- [ ] Evaluate `nexus.ecs.native` vs Flecs (spike only; no switch required)

**Documentation**

- [ ] Full theory ↔ API audit
- [ ] [`examples/minimal-game.md`](examples/minimal-game.md) — rename narrative to **minimal-2d-game**
- [ ] Example gallery index in [`examples/README.md`](examples/README.md)
- [ ] Mark WASM §16 **shipped** (host API)

**Example:** `minimal-2d-game` — one shippable 2D title composing all prior rungs.

**Success criteria:**

- New developer reads examples 0.1.0→1.0.0 and understands the hybrid 2D model.
- Game builds with `zig build minimal-2d-game` and runs without editor.
- At least one data-only or WASM mod loads successfully.

---

### v1.1.0 — Crucible integration 🔧

**Documentation:** [`crucible/README.md`](crucible/README.md). Separate git repo (Link-editor); `EditorHost` remains in Nexus.

- Scene hierarchy dock, inspector, **2D viewport** (pan/zoom/grid)
- Play / pause / step; scene snapshot on stop
- **Dear ImGui hard dependency** — via `zgame.zimgui`
- **Does not** link Flecs directly — uses `EditorHost.getEcsComponents`
- File watcher → `EditorHost.reimport`, `EditorHost.reloadScene`

**Tier 1 gate:** zGameLib `zimgui` shipped (late optional module — after 2D batcher).

---

### v1.1.1 — Mod tooling (Crucible) 🔧

- Mod project templates (Zig, Rust)
- "Build Mod" button — WASM compile orchestration hidden from modder
- `EditorHost.reloadMod` → `ModManager.reload`
- `mod-demo` example — simple mod that spawns a `Sprite2D`

See [`theory/13-wasm-modding.md`](theory/13-wasm-modding.md).

---

### v1.2.0 — Localization 🔧

**Decisions (fixed):** Nexus-only; data-oriented; `.po` → JSON via **`build.zig`**;
`LocalizationSystem` query API with pluralization; ECS resolve on locale change; no ICU.

**Implementation**

- [ ] `build/compile_locale.zig` — PO → JSON step integrated in **`build.zig`**
- [ ] `LocalizationSystem` on `NexusContext` — `lookup`, `lookupPlural`, `setLocale`
- [ ] `CompiledLocaleData` resource — loaded from `res://locale/<tag>.json`
- [ ] `tr()` / `tr_n()` sugar on `NexusContext`
- [ ] ECS `LocalizedText` + resolve pass on locale change
- [ ] `project.nexus` default locale + `locale_fallbacks`
- [ ] Crucible: `.po` edit/preview workflow
- [ ] **Proving example:** `i18n-demo`

**Documentation**

- [x] `Nexus_Reference.md` §14 — runtime + build pipeline specified
- [x] [`theory/07-localization-system.md`](theory/07-localization-system.md)
- [ ] Mark §14 **shipped** when code lands

---

## Post–first 2D game (v2.x) ⏳

Open **only after** v1.0.0 ships and the 2D example ladder is proven.

### v2.0.0 — 3D smoke

- [ ] `Node3D`, `Camera3D`; perspective projection in `RenderingServer`
- [ ] Basic mesh draw (interim or zGameLib `hello-cube` path)
- [ ] Example: `hello-3d` — rotating cube or textured mesh
- [ ] Crucible: orbit viewport, 3D gizmo (Link-editor v2.0.0)

**Tier 1 gate:** zGameLib depth buffer + `hello-cube`.

### v2.1.0 — 3D content + physics

- [ ] glTF mesh import via zClip
- [ ] Jolt 3D behind `PhysicsServer` (3D backend)
- [ ] Example: `gltf-scene`

### v2.2.0 — Multiplayer (GNS)

- [ ] GNS sibling adapter in zGameLib (optional module)
- [ ] Nexus `MultiplayerAPI` — sessions, RPC, replication stub
- [ ] Example: `net-pong` (2D gameplay over network proves API)
- [ ] Full commitment to GNS — no ENet ([theory/11](theory/11-networking-decision.md))

### v2.3.0 — Web target

- [ ] WASM + WebGPU backend alignment ([theory/12](theory/12-web-backend-strategy.md))
- [ ] Same mod `.wasm` packages run on desktop and web

---

## Example ladder summary

```ascii
v0.1.0  clear-color        NexusApp owns the loop                    🎯
v0.2.0  textured-quad      + Sprite2D / Node2D
        node-hierarchy     + tree UX
v0.3.0  ecs-basic          + Flecs attach (no sync)
v0.4.0  hybrid-sync        + bridge sync
v0.5.0  simple-movement    + InputMap
v0.6.0  camera             + Camera2D (2D only)
v0.7.0  particles          + ECS-only 2D heat
v0.8.0  debug-ui           + overlay + scene load
v0.9.0  physics-ball       + PhysicsServer2D + hot reload
v1.0.0  minimal-2d-game    + FIRST 2D SHIP + WasmHost
v1.1.0  (editor)           + Crucible 2D tools                        🔧
v1.1.1  mod-demo           + WASM build abstraction                   🔧
v1.2.0  i18n-demo          + LocalizationSystem                       🔧
v2.0.0  hello-3d           + 3D smoke                                 ⏳
v2.1.0  gltf-scene         + 3D content                               ⏳
v2.2.0  net-pong           + GNS multiplayer                          ⏳
```

Build: `zig build <example>` · Design: [`docs/examples/<name>.md`](examples/)

---

## Development workflow

Same discipline as [zGameLib](../libs/zGameLib/docs/ROADMAP.md):

1. **API first** — document in `Nexus_Reference.md`, then contract tests (`zig build test`).
2. **TDD** — red→green behavioral tests (`zig build test-tdd`) where display/GPU needed.
3. **Example proves integration** — each minor that adds user-visible capability ships an example doc + target.
4. **No GPL/LGPL/AGPL** — clean-room only.

---

## macOS platform policy

**In scope — not deferred.** Cocoa/Metal behavior follows Redot clean-room study;
CI runs `zig build` on macOS VMs; **contributors** validate windowed examples on real
hardware. Details: [zGameLib macOS policy](../libs/zGameLib/docs/ROADMAP.md#macos-platform-policy).

---

## Tier 1 alignment

| Nexus version | Needs from zGameLib | Priority |
|---------------|---------------------|----------|
| 0.1.0 | `Gpu`, `FrameRing` ✅ | 🎯 |
| 0.2.0 | Image decode + 2D batcher v0 | 🎯 |
| 0.3.0–0.4.0 | Stable Vulkan 2D pipelines | 🎯 |
| 0.5.0+ | Input depth (platform adapter) ✅ | 🎯 |
| 0.6.0–0.7.0 | 2D batcher maturity | 🎯 |
| 0.9.0 | Optional: `zaudio` for 1.0.0 game | 🎯 |
| 1.0.0 | `zassets` stable; zClip sprite atlas | 🎯 |
| 1.1.0 Crucible | zGameLib `zimgui` (**late**) | 🔧 |
| 1.2.0 i18n | `.po` compile + JSON in Nexus only | 🔧 |
| 2.0.0 3D | zGameLib depth + `hello-cube` | ⏳ |
| 2.1.0 3D | zClip glTF skeletal | ⏳ |
| 2.2.0 net | GNS sibling | ⏳ |

---

## Long-term vision

| Pillar | Direction |
|--------|-----------|
| **2D-first** | Ship one 2D game before 3D investment |
| **Hybrid** | Nodes for authoring; ECS where profiling demands |
| **Separation** | zGameLib / Nexus / Crucible — three tiers, explicit boundaries |
| **Data-driven** | Scenes, locale, mods on disk; compile in `build.zig` |
| **Modding** | WASM sandbox; Crucible hides toolchain |
| **UI** | ImGui for tools only; in-game HUD via 2D batcher |
| **i18n** | Data-oriented `LocalizationSystem`; `.po` → JSON compile |
| **Never** | Replace SceneNode tree with pure ECS |
| **ECS adapter** | Flecs first; optional native Zig ECS behind same interface |

---

## Risks

| Risk | Mitigation |
|------|------------|
| Docs ahead of code | Version tags mark **shipped** vs **planned** in `Nexus_Reference.md` |
| zGameLib 2D batcher slips | Interim quad renderer in `RenderingServer` |
| 3D scope creep pre-1.0 | Explicit 🎯/⏳ markers; `Camera3D` gated to v2.0.0 |
| Flecs ABI friction | Isolate in `nexus.ecs.flecs`; swappable adapter |
| Crucible scope creep | `EditorHost` v1 frozen at 1.0.0; 2D viewport first |
| WASM modder friction | Data-only mods; Crucible templates at v1.1.1 |