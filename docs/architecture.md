# Nexus Engine — Architecture Overview

> **Full reference:** [`Nexus_Reference.md`](Nexus_Reference.md)  
> **Deep dive:** [`theory/README.md`](theory/README.md)

This repository (**Nexus-engine**) is **Nexus Engine** (Tier 2) on **zGameLib**
(Tier 1). *Forge* is an alias for Nexus Engine. **Link-editor** (Tier 3) is the
detachable editor (*Crucible* is an alias).

## 3-tier stack

```
┌──────────────────────────────────────────────────────────────┐
│  TIER 3: LINK-EDITOR (Editor)                                   │
│    Dear ImGui · SceneNode editing · ECS inspect via Nexus Engine    │
└───────────────────────────────┬──────────────────────────────┘
                                │ EditorHost
┌───────────────────────────────▼──────────────────────────────┐
│  TIER 2: NEXUS ENGINE (this repo)                                   │
│    Hybrid SceneNode tree + optional ECS (Flecs first)        │
│    Servers · resources · project settings · scripting        │
└───────────────────────────────┬──────────────────────────────┘
                                │ zgame.*
┌───────────────────────────────▼──────────────────────────────┐
│  TIER 1: zGAMELIB                                            │
│    platform · Vulkan · FrameRing · (planned) audio/assets    │
└──────────────────────────────────────────────────────────────┘
```

Nexus Engine is **just another consumer** of zGameLib — it can re-export, wrap, or bypass
the foundation when raw access is needed.

## Hybrid model (summary)

- **SceneNodes** — authoring, serialization, Link-editor, Godot-like gameplay API
- **ECS (optional)** — physics, render gather, crowds; synced via `EcsBridge`
- **Servers** — Redot-style rendering/audio/physics facades over Tier 1 primitives

See [`theory/01-scene-representation.md`](theory/01-scene-representation.md) and
[`theory/02-ecs-integration.md`](theory/02-ecs-integration.md).

## Design principles

| Principle | Nexus Engine |
|-----------|-------|
| Raw-first | `zgame` APIs remain reachable from game code |
| Servers over monoliths | Swappable backends + dummy servers |
| Explicit | Vulkan-only graphics |
| Hybrid by default | Nodes for UX; ECS where profiling demands |

## Dependency graph

```
┌────────────────────────────────────────┐
│  Nexus Engine (Tier 2)                        │
│  • SceneTree / SceneNode / EcsBridge   │
│  • ResourceDB · NexusApp               │
│  • RenderingServer · PhysicsServer · … │
├────────────────────────────────────────┤
│  zGameLib (Tier 1)                     │
│  • platform · Gpu · FrameRing          │
│  • vk · shaderc · zclip                │
│  • (planned) zaudio · zassets · zmath  │
└────────────────────────────────────────┘
```

The engine links `zgame` via `build.zig.zon` (local path `../zGameLib`).

## Repository layout & dependencies

| | This repo (Tier 2) | zGameLib (Tier 1) |
|--|--|--|
| Layout | [`file-tree.yml`](file-tree.yml) | [`../zGameLib/docs/file-tree.yml`](../zGameLib/docs/file-tree.yml) |
| Dependencies | [`dependencies.yml`](dependencies.yml) | [`../zGameLib/docs/dependencies.yml`](../zGameLib/docs/dependencies.yml) |

## macOS

**In scope — not deferred.** Platform behavior follows Redot clean-room study
(Cocoa/Metal via zGameLib). CI runs `zig build` on macOS VM runners; contributors
own windowed/runtime validation on real hardware. Details:
[`ROADMAP.md` § macOS](ROADMAP.md#macos-platform-policy).

## Current state

Early bootstrap — documented architecture ahead of implementation:

- zGameLib wired; platform + Vulkan window at startup (`src/main.zig`)
- Hybrid scene/ECS, servers, resources: **documented** (see theory ladder)
- Link-editor `EditorHost`: **specified** in `Nexus_Reference.md`

Next releases (see [`ROADMAP.md`](ROADMAP.md)): **v0.0.1** bootstrap → **v0.1.0**
`clear-color` → **v0.2.0** scene nodes → **v0.3.0–0.4.0** ECS bridge.

Example design docs: [`examples/ladder.md`](examples/ladder.md).