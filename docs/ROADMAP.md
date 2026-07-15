# Nexus-engine Roadmap

**Goal:** Build a modern, hybrid game engine (Tier 2) on top of zGameLib. Clean-room modernization inspired by Redot/Godot — retained nodes for authoring, optional ECS for hot paths, explicit control, and Vulkan-only rendering.

**Aliases:** Nexus Engine = *Forge* · Link-editor = *Crucible*

**Companion docs:** [`Nexus_Reference.md`](Nexus_Reference.md) · [`architecture.md`](architecture.md) · [`theory/README.md`](theory/README.md) · [`file-tree.yml`](file-tree.yml) · [`dependencies.yml`](dependencies.yml)

**Tier 1 roadmap:** [`../zGameLib/docs/ROADMAP.md`](../zGameLib/docs/ROADMAP.md) (zGameLib `feat/engine-docs-ref`)

> **Influenced by Casey Muratori's Handmade Hero philosophy** (via zGameLib): thin
> platform layer, explicit control, replaceable pieces, raw access always available,
> and no framework magic.

---

## Philosophy

Nexus Engine inherits zGameLib's design axioms and adds Tier-2 rules for game
architecture. The engine is **optional middleware over zGameLib** — games can
always drop through to `zgame.*`.

### Key principles

| Principle | What it means in Nexus Engine |
|-----------|-------------------------------|
| **Pay for what you use** | Only the servers and subsystems your game registers are active. Dummy backends for headless CI; no physics server unless you add one. |
| **Raw-first** | Every server is implemented *on top of* zGameLib primitives. `zgame.platform`, `zgame.Gpu`, `zgame.FrameRing` remain importable from game code. |
| **Thin abstraction** | Small, stable public surfaces. Flecs, Jolt, and Vulkan details stay behind adapters — not in `SceneNode` APIs. |
| **Explicit control flow** | No hidden `_process` magic, no implicit singletons. `NexusApp.tick()` phases are documented and traceable. |
| **Replaceable pieces** | Servers have swappable backends (`RenderingServer`, `PhysicsServer`). ECS adapter is swappable (`flecs` → native Zig). |
| **Hybrid by default** | SceneNodes for authoring and UX; ECS opt-in for hot paths. Never replace the tree with pure ECS. |
| **Composition, not inheritance** | `MeshInstance3D` embeds `SceneNode`; servers compose over zGameLib — no deep framework hierarchies. |
| **Performance as a first-class concern** | Benchmarks and profiler hooks are part of the engine, not an afterthought. |
| **Clean-room** | Redot/Godot inform *behavior*, not code. Port only what usage audits prove necessary. |

### Tier-specific rules

- **Tier 1 boundary:** Window, events, GPU bring-up, decode — zGameLib. Nexus re-exports or wraps; it does not reimplement.
- **Tier 2 boundary:** Scene tree, servers, resources, input *actions*, tick loop — Nexus Engine.
- **Tier 3 boundary:** Dear ImGui, inspectors, gizmos — Link-editor (Crucible). Consumes `EditorHost`; not baked into the engine binary.

### macOS platform policy

macOS is **in scope — not deferred.** Tier 1 macOS behavior (Cocoa window,
MoltenVK surface) follows **Redot clean-room study** — same hand-off model as
zGameLib's platform + vulkan adapters; no Redot source in the tree.

| Layer | macOS testing |
|-------|----------------|
| **CI (this repo)** | `zig build` on `macos-latest` runners (container/VM pipeline). `zig build run` may fail without a display — same class of limitation as headless Linux. |
| **Contributors** | Windowed/runtime validation on **real macOS hardware** before macOS-specific PRs merge. |

See also [zGameLib macOS policy](../zGameLib/docs/ROADMAP.md#macos-platform-policy).

---

## Development Workflow

Nexus Engine follows the same **test-first, API-first** discipline as zGameLib and
its sibling libraries.

### API first, then implementation

1. **Specify the public contract** in [`Nexus_Reference.md`](Nexus_Reference.md) (or a
   focused `docs/api/<module>.md` when a subsystem grows).
2. **Write contract tests** (`zig build test`) that compile against the API and
   assert types, error sets, and data invariants — no GPU/display required.
3. **Implement behind the contract** — replace stubs, keep the public surface stable.
4. **Prove behavior** with the TDD suite (`zig build test-tdd`) and/or example
   rungs where integration requires a display.

Public APIs use **explicit error sets**, named types, and documented ownership.
No inferred `!T` on engine surfaces consumers must `switch` on.

### TDD approach

| Step | Command | What it is | When it runs |
|------|---------|------------|--------------|
| **Contract** | `zig build test` | API/data tests — `SceneTree` invariants, `NodeId` uniqueness, server trait signatures. No display. | **Gates CI** — must always be green. |
| **Behavioral** | `zig build test-tdd` | Ordered red→green suite. Each test calls real functions with a `// WHEN … · GIVEN … · THEN …` spec. | Local + CI where display/Vulkan available. |
| **Integration** | `zig build <example>` | Example ladder rungs — end-to-end proof the engine composes with zGameLib. | CI builds + runs per landed rung. |

**House rules (same as zGameLib):**

- Every feature lands via a gated TDD session: **red → green**, one atomic commit per concern.
- Do **not** disable, comment out, or weaken a test to make something pass. Fix the test in the same PR if the contract was wrong — and say so.
- `zig fmt --check .` stays green on every PR.
- New functionality adds a **contract test** or a **new example rung** (or both).

### Definition of done (per task)

- [ ] Public API documented in reference docs before or with the implementation PR.
- [ ] `zig build test` green (contract suite).
- [ ] Behavioral tests green where applicable (`zig build test-tdd`).
- [ ] Example rung updated or added if the feature is user-facing.
- [ ] No GPL / LGPL / AGPL dependencies introduced.

---

## Example Ladder (not shipped with the engine)

Examples are **reference applications** — the same model as
[zGameLib's example ladder](https://github.com/SETA1609/zGameLib/tree/main/docs/examples).
They are **not** part of the `nexus-engine` binary and **not** embedded in the engine
library artifact.

```
nexus-engine (zig build)          → engine module + minimal boot executable
examples/<name>/ (zig build <name>) → standalone consumer apps, one capability per rung
docs/examples/                    → per-example design docs, ladder, vision/mission
```

### Three jobs, every example

| Job | What it means |
|-----|---------------|
| **Integration test** | Drives Nexus + zGameLib together — paths unit tests cannot reach. |
| **Usage reference** | Shows a consumer wiring `nexus.*` the canonical way (import module, register servers, build a scene). |
| **Modularity proof** | Proves adding a capability does not pull in unrelated servers (e.g. physics-free rung has zero physics symbols). |

### Example principles (from zGameLib)

- Each rung adds **exactly one new engine capability**.
- Examples are **complete, runnable apps** — copy the import/link pattern into your game.
- Examples stay **focused toys**, not a second engine. Duplication between examples is fine.
- Design docs live in `docs/examples/`; source lives in `examples/`. The engine ships neither in its default artifact.
- A consumer reads an example's source and replicates the pattern — same as zGameLib's `event-logger` → `clear-color` ladder.

### Planned rungs

| # | Example | What it proves | Phase |
|---|---------|----------------|-------|
| **0** | `hello-nexus` | `NexusApp` boot, empty scene, clear-color via `RenderingServer` | Phase 0 |
| **1** | `colored-quad` | `SceneTree` + `Node2D` + drawable node | Phase 1 |
| **2** | `sprite-demo` | `ResourceDB` texture + `Sprite2D` | Phase 1 |
| **3** | `moving-sprite` | `InputMap` + `process` traversal | Phase 2 |
| **4** | `physics-ball` | `PhysicsServer` + `EcsBridge` transform sync | Phase 2 |
| **5** | `particle-storm` | ECS-only entities (no `SceneNode` per particle) | Phase 2 |
| **6** | `minimal-3d` | `Node3D` + mesh instance smoke test | Phase 2+ |

See `docs/examples/` (scaffolded with the first implementation rung).

---

## Licensing & Contributing

Nexus Engine follows the **same licensing and contribution model as zGameLib**.

### License

- Nexus Engine is **Apache License 2.0** — permissive; use in commercial and
  closed-source products without releasing your own source.
- New `.zig` source files carry the standard header:

```zig
//! SPDX-License-Identifier: Apache-2.0
//! Copyright 2026 Sebastian Tamayo (SETA1609)
```

- Attribution: ship `LICENSE` + `NOTICE` with distributions (see `LICENSING.md` when added).
- zGameLib and its sibling libraries remain under their own permissive licenses
  (Apache-2.0 / MIT / Zlib). Those obligations travel with your binary.

### Legal constraints

- **No GPL / LGPL / AGPL dependencies — ever.**
- Do not copy code from LGPL/GPL projects (including Redot/Godot source). Clean-room
  reimplementation from documented behavior only.
- Contributions are licensed under the repo's **Apache-2.0** license. By submitting
  a PR you agree to license your contribution under Apache-2.0. **No CLA required.**

### Commits & PRs

- **Conventional Commits** (`feat:` / `fix:` / `docs:` / `chore:` / `ci:` / `test:`),
  atomic — one concern per commit, subject ≤ 72 chars.
- Small fixes: open a PR directly. **Larger work (new server, API change): open an issue first.**
- New functionality should add a contract test and/or an example rung.
- Cross-language FFI (if any C/C++ is added for physics or ECS adapters): C-compatible
  types only across the ABI; `export fn` for Zig→C; `noexcept` + catch on C++→C bridges.

### Dev setup

```sh
zig build                 # engine module + nexus-engine executable
zig build test            # contract suite (gates CI)
zig build test-tdd        # behavioral suite (display + Vulkan where needed)
zig build hello-nexus     # example rung 0 (once landed)
```

Full contribution guide: `CONTRIBUTING.md` (to be added; mirrors zGameLib sibling libs).

---

## Current Status (July 2026) — Verified

| Area | State | Evidence |
|------|-------|----------|
| **Documentation** | Strong, implementation-ready | `docs/Nexus_Reference.md`, `docs/architecture.md`, theory ladder `00–05`, legacy Redot analysis |
| **Architecture design** | Complete on paper | Hybrid SceneNode + ECS, server model, `EditorHost` API, tick pipeline |
| **Implementation** | Bootstrap only | Single file `src/main.zig` — platform init, Vulkan window, event poll loop |
| **Module layout** | Not started | No `src/nexus/`, no `nexus` Zig module; executable root is `main.zig` |
| **ECS / scene / servers** | Documented only | No `SceneNode`, `EcsBridge`, `NexusApp`, `RenderingServer` in code |
| **Tests** | None | No `zig build test` step |
| **Build / CI** | Green | `zig build` passes; CI matrix Ubuntu/macOS/Windows — macOS build in VM pipelines; runtime on Mac hardware by contributors (see below) |
| **zGameLib (Tier 1)** | Partially ready | Platform, Vulkan, `Gpu`, `FrameRing` shipped; 2D batcher, `zassets`, `zaudio` still planned |
| **Link-editor (Tier 3)** | Spec only | `EditorHost` in reference docs; no Crucible repo in workspace |

**Bottom line:** The project is at the end of the design phase and the start of Phase 1. Theory docs are ahead of the code — the right order — but Phase 1 should begin with project scaffolding, not jumping straight to rendering.

---

## Tier Boundaries (non-negotiable)

```ascii
Link-editor (Crucible)     edits SceneNodes, reads ECS via Nexus APIs
        │
Nexus-engine (Forge)       SceneTree · EcsBridge · Servers · Resources · NexusApp
        │
zGameLib (Tier 1)          platform · vk · Gpu · FrameRing · decode · audio
```

- Raw `zgame.*` stays reachable from game code.
- Flecs (or future native ECS) stays behind `nexus.ecs` — never in the public SceneNode API.
- Link-editor never links Flecs directly.

---

## Phase 0: Bootstrap (July 2026)

Get the repo structure to match the docs. Small, but unblocks everything else.
Work is **API-first + TDD**: stub public types in `nexus/root.zig`, contract tests
first, then minimal implementation.

- [ ] Add `LICENSE`, `NOTICE`, `LICENSING.md`, `CONTRIBUTING.md` (Apache-2.0; mirror zGameLib)
- [ ] Split executable vs engine module: `src/main.zig` + `src/nexus/root.zig` exported as `nexus` module in `build.zig`
- [ ] Establish `src/nexus/` layout:
  - `scene/` — `SceneNode`, `SceneTree`
  - `ecs/` — Flecs adapter stub
  - `runtime/` — `NexusApp`, `NexusContext`
  - `servers/` — rendering (first), dummy backends for headless
  - `resources/` — loader skeleton
- [ ] Add `zig build test` — contract suite for `NexusApp`, `SceneTree` invariants
- [ ] Add `zig build test-tdd` step (scaffold; first behavioral tests in Phase 1)
- [ ] Wire `NexusApp.init` to replace raw loop in `main.zig` (clear-color or noop tick)
- [ ] Scaffold `examples/hello-nexus/` + `docs/examples/hello-nexus.md` (rung 0; not linked into engine artifact)
- [ ] Document implementation status table in `docs/architecture.md`

**Exit criteria:** `zig build` + `zig build test` green; `main.zig` calls `nexus.NexusApp`; `hello-nexus` example builds separately; no engine logic in `main.zig` beyond boot.

---

## Phase 1: Core Foundation (Q3 2026)

Foundation layer — no editor, no physics yet. Goal: one colored quad or textured sprite on screen through Nexus APIs, not raw zGameLib calls in `main`.

### 1.1 Scene layer

- [ ] Document `SceneNode` / `SceneTree` API in `Nexus_Reference.md` §4 (freeze v1 surface)
- [ ] Contract tests for `SceneNode` add/remove/reparent, deferred delete, pause propagation
- [ ] Define stable `SceneNode` struct + `NodeId`, `NodeFlags`, `EcsLink` (per [`theory/01`](theory/01-scene-representation.md))
- [ ] `SceneTree`: root, pause mode, enter/exit tree, deferred delete queue
- [ ] `Node2D` / `Node3D` with local transform + hierarchical world matrix
- [ ] Minimal signals stub (connect/emit for `tree_entered` / `tree_exited`)
- [ ] Tree traversal hooks: `process`, `physicsProcess` (empty vtable defaults)

### 1.2 Runtime

- [ ] `NexusApp` + `NexusContext` — owns window, tree, server registry
- [ ] `NexusApp.tick()` implementing phases 1–5 from [`theory/03`](theory/03-systems-and-update-loop.md) (GPU stub in phase 1)
- [ ] Fixed/variable timestep accumulator (physics step runs, even if empty)

### 1.3 ECS bridge (stub)

- [ ] `nexus.ecs.flecs` — thin Flecs wrapper (`World`, `Entity`, `Phase`)
- [ ] `EcsBridge` — `attach` / `detach` on tree enter/exit; no sync yet
- [ ] `NodeId` component on mirrored entities

### 1.4 Resources (minimal)

- [ ] `ResourceDB` skeleton — path → handle, refcount, `res://` VFS root
- [ ] Texture load via zGameLib image decode → GPU upload handle
- [ ] Shader resource stub (SPIR-V blob + metadata)

**Tier 1 gate:** Image decode path must exist in zGameLib (or a minimal Nexus-side loader using existing Vulkan upload helpers). `zassets` full VFS can wait — start with filesystem `res://`.

### 1.5 Rendering

- [ ] `RenderingServer` facade over zGameLib `Gpu` + `FrameRing`
- [ ] Dummy `RenderingServer` for headless CI (no swapchain)
- [ ] 2D path: colored quad **or** textured sprite
  - If zGameLib 2D batcher is not ready: implement a minimal quad renderer inside `RenderingServer` (document as temporary; migrate when batcher lands)
- [ ] `Sprite2D` / `MeshInstance` node types that register draw instances with the server
- [ ] ECS `render_gather` system stub (collect draw list from mirrored nodes)

### 1.6 Example rungs (reference apps — not shipped with engine)

- [ ] `examples/colored-quad/` + `docs/examples/colored-quad.md` — scene in code, rendered via `NexusApp.tick()`
- [ ] `examples/sprite-demo/` + `docs/examples/sprite-demo.md` — textured sprite via `ResourceDB`
- [ ] `zig build colored-quad` / `zig build sprite-demo` as separate build steps (like zGameLib examples)

**Exit criteria:** Window shows a quad/sprite; scene is a `SceneTree` with at least one drawable node; example rungs build + run; CI uses dummy renderer when display unavailable.

---

## Phase 2: Systems & ECS Integration (Q4 2026)

Make the hybrid model real — sync, input, physics hook, assets.

### 2.1 ECS integration (full bridge)

- [ ] Proper ECS integration with SceneNode (optional link per node)
- [ ] `EcsBridge` sync policies: `node_authoritative`, `ecs_authoritative`, `sim_only`
- [ ] Transform sync both directions (`syncTransformsToNodes` / `syncTransformsToEcs`)
- [ ] Component registration: `Transform`, `Velocity`, `DrawInstance`
- [ ] Opt-in `ecs_mirrored` flag on `SceneNode`

### 2.2 Transform system

- [ ] Hierarchical transform propagation on node tree
- [ ] Dirty-flag propagation → ECS bulk update
- [ ] `Node3D` gizmo-ready world transform query API (for future Crucible)

### 2.3 Input

- [ ] `InputMap` — action names → key/gamepad bindings (Tier 2)
- [ ] Re-export raw events from `zgame.platform` via `DisplayServer` / input facade
- [ ] `process` phase reads actions; example: move sprite with WASD

### 2.4 Physics (first integration)

- [ ] `PhysicsServer` trait + `DummyPhysicsServer`
- [ ] Simple physics integration (start with Jolt or 2D physics)
- [ ] ECS physics phase in fixed step; `RigidBody3D` node type
- [ ] Bridge: physics writes ECS transforms → sync to nodes

### 2.5 Assets

- [ ] Asset hot-reloading support (file mtime → `ResourceReloaded` signal)
- [ ] Mesh load path (glTF via zGameLib / cgltf)
- [ ] Basic material / texture binding

### 2.6 Example rungs

- [ ] `examples/moving-sprite/` + `docs/examples/moving-sprite.md` — input-driven sprite
- [ ] `examples/physics-ball/` + `docs/examples/physics-ball.md` — falling box or bouncing ball
- [ ] `examples/particle-storm/` + `docs/examples/particle-storm.md` — ECS-only entities, no `SceneNode` per particle

**Exit criteria:** Input-driven scene; at least one physics interaction; hot-reload reloads a texture without restart.

---

## Phase 3: Editor Integration & Tooling (Q1 2027)

Crucible as a detachable Tier 3 consumer — not baked into the engine binary.

### 3.1 EditorHost API

- [ ] Implement `EditorHost` from [`Nexus_Reference.md`](Nexus_Reference.md) §9
- [ ] `getSceneTree`, `setProperty`, selection, undo transaction stubs
- [ ] `playInEditor` / `stopInEditor` — spawns child `NexusContext` with same tick pipeline

### 3.2 Crucible (separate repo or workspace)

- [ ] Integrate with **Crucible** editor (Scene hierarchy view)
- [ ] Inspector for SceneNode + ECS components
- [ ] ECS debug panel via `getEcsComponents` (read-only first)
- [ ] Use Dear ImGui (via zGameLib optional module) for editor UI
- [ ] Viewport gizmo → writes node transform

### 3.3 Play mode

- [ ] Play mode + pause/step controls
- [ ] Entity/Component editing in real time
- [ ] Scene state snapshot + restore on stop
- [ ] Editor vs runtime server selection (dummy vs live renderer)

**Exit criteria:** Edit node name/transform in Crucible; press Play; see changes in viewport; Stop restores edit state.

**Prerequisite:** Phase 1–2 scene + property APIs stable enough to freeze `EditorHost` v1.

---

## Phase 4: Polish & Performance (2027)

### 4.1 Profiling & optimization

- [ ] Performance profiling & optimization
- [ ] Frame profiler: node traversal ms, ECS phase ms, bridge sync ms, GPU ms
- [ ] Targets from [`theory/04`](theory/04-performance-considerations.md): 1k mirrored entities, 10k ECS-only entities benchmark
- [ ] Object pooling for nodes, entities, draw commands

### 4.2 ECS evolution

- [ ] Optional pure custom Zig ECS (evaluate replacing Flecs)
- [ ] `nexus.ecs.native` behind same `World`/`Entity` interface
- [ ] Migration criteria: Flecs ABI friction, comptime layout needs, multithread policy
- [ ] **SceneNode API unchanged** — adapter swap only

### 4.3 Memory & servers

- [ ] Better memory management & pooling
- [ ] Arena/pool allocators per frame for transient command buffers
- [ ] `AudioServer` when zaudio lands in zGameLib
- [ ] Navigation / text servers — stubs only unless game project demands

### 4.4 Release prep

- [ ] Documentation completion + examples
- [ ] Documentation pass: theory docs ↔ implemented API
- [ ] Example gallery (quad, sprite, physics, particles, minimal 3D)
- [ ] `project.nexus` settings file (minimal)
- [ ] **First usable alpha release (v0.1)** — ship a game without Crucible; editor optional

**Exit criteria:** Documented alpha; benchmark suite; one sample game (e.g. simple 2D platformer) built only on Nexus APIs.

---

## Long-term Vision

| Pillar | Direction |
|--------|-----------|
| **Architecture** | Hybrid retained + data-oriented (Unity DOTS-style opt-in, not replacement) |
| **Separation** | zGameLib = foundation; Nexus = game systems; Crucible = tooling |
| **Rendering** | Vulkan-only; servers abstract zGameLib evolution (batcher, PBR later) |
| **Scripting** | Zig-first; guest WASM or embedded scripting evaluated post-alpha |
| **Serialization** | `.fscn` packed scenes; `res://` UID model per [`theory/05`](theory/05-resource-and-asset-management.md) |
| **Never** | Replace SceneNode tree with pure ECS for authoring |

- Hybrid retained + data-oriented architecture (like Unity DOTS)
- Strong separation between zGameLib (foundation) and Nexus-engine (game systems)
- Detachable editor (Crucible)
- Excellent tooling and debuggability

---

## Tier 1 Alignment (zGameLib — July 2026)

Nexus phases gate on the [zGameLib roadmap](../zGameLib/docs/ROADMAP.md). Summary of
what Tier 1 is delivering and how it unblocks Forge:

| zGameLib phase | Tier 1 deliverables | Nexus impact |
|----------------|---------------------|--------------|
| **Q3 2026 — Core completion** | Vulkan pipelines/descriptors stable; `zaudio` (miniaudio); optional `-DimGui`; glTF + image decode (`zassets`); 2D batcher/sprites/text; `hello-triangle`; zClip A1 `sprite-showcase` | Phase 0–1 rendering + textures; interim quad renderer only if batcher slips |
| **Q4 2026 — Polish** | Diagnostics; textured examples; ImGui guide; KTX/Basis helpers; validation apps (snake → space-invaders); zClip A2 `gltf-viewer` | Phase 2 assets/meshes; richer sprite demos |
| **2027 — Expansion** | Fonts; optional ENet; Tracy; full asset pipeline; zClip A3–A4; `zgame.App` | Phase 4 audio/fonts; Crucible may use `-DimGui`; alpha release prep |

**zGameLib example tracks** (reference only — not shipped with Nexus):

- **Track A:** modular capability rungs (`event-logger` → `app-demo`) — [`../zGameLib/docs/examples/ladder.md`](../zGameLib/docs/examples/ladder.md)
- **Track B:** extended validation apps (snake, `hello-cube`, …)
- **Track C:** zClip animation (`sprite-showcase`, `gltf-viewer`, …) — sprite path **shipped** at zClip v0.6

---

## Dependency Map (zGameLib → Nexus)

| Nexus needs | zGameLib status | zGameLib phase | Nexus phase |
|-------------|-----------------|----------------|-------------|
| Window + events | Shipped | — | Phase 0 ✓ |
| `Gpu` + `FrameRing` | Shipped | — | Phase 0–1 ✓ |
| 2D batcher / sprites / text | Planned Q3 2026 | Phase 1 | Phase 1 — interim `RenderingServer` quad if needed |
| Image decode → GPU | Planned Q3 2026 (`zassets`) | Phase 1 | Phase 1 textures |
| glTF / mesh | Partial (zClip skeletal in progress) | Phase 1–2 | Phase 2 meshes |
| `zassets` VFS | Planned Q3–Q4 2026 | Phase 1–2 | Phase 2 — Nexus `res://` may lead |
| `zaudio` / miniaudio | Planned Q3 2026 | Phase 1 | Phase 4 `AudioServer` (can start earlier if zaudio lands) |
| `zclip` sprite-atlas | Shipped v0.6 | Phase 1 | Phase 2 animation nodes |
| Dear ImGui (`-DimGui`) | Planned Q3 2026 | Phase 1 | Phase 3 Crucible (Tier 3) |
| `zmath` | Planned | Phase 1+ | Phase 1 transforms |
| `zgame.App` harness | Stub → 2027 | Phase 3 | Optional — Nexus keeps `NexusApp` |

Nexus should not block on full zGameLib v1.0 — but Phase 1 rendering and Phase 2 assets need explicit Tier 1 Phase 1 rungs or thin Nexus-side stopgaps.

---

## Repository Layout

Canonical layout for this repo:
[`file-tree.yml`](file-tree.yml) — target tree with `status` per node:
`shipped` · `partial` · `stub` · `planned` · `legacy`.

Tier 1 (zGameLib) docs live in the dependency repo (sibling path or git submodule):

- Layout: [`../zGameLib/docs/file-tree.yml`](../zGameLib/docs/file-tree.yml)
- Dependencies: [`../zGameLib/docs/dependencies.yml`](../zGameLib/docs/dependencies.yml)

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| zGameLib 2D batcher not ready for Q3 | Minimal `RenderingServer` quad path; migrate later |
| Flecs C ABI in Zig build | Isolate in `nexus.ecs.flecs`; compile-only CI test |
| CI `zig build run` fails headless | Dummy `RenderingServer`; run step gated on display |
| Scope creep (full Godot parity) | Clean-room audit: add node types only when examples need them |
| Crucible scope | Freeze `EditorHost` v1 after Phase 2; editor is Tier 3, not blocking alpha |

---

## Immediate Next Steps

1. **Legal scaffold** — `LICENSE`, `NOTICE`, `CONTRIBUTING.md` (Apache-2.0, mirror zGameLib)
2. **Phase 0** — `nexus` module + directory layout + `NexusApp` API stub
3. **Contract tests first** — `SceneTree` add/remove child, deferred delete (`zig build test`)
4. **`NexusApp.tick()`** — implement behind contract; wire zGameLib poll + clear-color
5. **Rung 0** — `examples/hello-nexus/` as a separate build target, documented in `docs/examples/`