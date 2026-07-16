# The theory of Nexus — a reading path

> **Official name:** **Nexus** (repository: `Nexus-engine`, Tier 2). *Forge* = runtime alias.
> **Crucible** (Tier 3 editor) — docs in [`../crucible/README.md`](../crucible/README.md).

This folder explains **why and how** the hybrid engine is shaped: retained `SceneNode`
hierarchy, **Flecs adapter** (native Zig ECS only if needed later), opinionated immediate-mode
tool UI, data-oriented localization direction, update loop, and Tier boundaries.

**Example-driven:** read each chapter as the matching version lands ([`../ROADMAP.md`](../ROADMAP.md)).

**Prerequisite:** zGameLib basics — open a window, clear color ([zGameLib theory](https://github.com/SETA1609/zGameLib/tree/main/docs/theory)).

---

## The mental model: three tiers

```ascii
┌─────────────────────────────────────────────────────────────────┐
│  CRUCIBLE (Tier 3) — edits SceneNodes; reads ECS via EditorHost │
├─────────────────────────────────────────────────────────────────┤
│  NEXUS ENGINE (Tier 2) — THIS DOCUMENTATION                     │
│    SceneTree · EcsBridge · Servers · Resources · NexusApp       │
├─────────────────────────────────────────────────────────────────┤
│  zGAMELIB (Tier 1) — platform · Vulkan · decode · audio · math  │
└─────────────────────────────────────────────────────────────────┘
```

**Golden rule (from zGameLib):** raw-first / opt-in. Drop to `zgame.vk` when a server blocks you.

**Nexus rules:** hybrid-by-default (nodes + optional ECS); immediate mode for tools; semi-retained UI only when necessary; Flecs adapter first.

---

## Theory ↔ releases ↔ examples

Read theory chapters as the matching **version** lands (see [`../ROADMAP.md`](../ROADMAP.md)).

| Version | Example(s) | Read theory |
|---------|------------|-------------|
| 0.1.0 | `clear-color` | [03](03-systems-and-update-loop.md) (loop phases intro) |
| 0.2.0 | `textured-quad`, `node-hierarchy` | [01](01-scene-representation.md), [05](05-resource-and-asset-management.md) |
| 0.3.0 | `ecs-basic` | [02](02-ecs-integration.md) (attach only) |
| 0.4.0 | `hybrid-sync` | [02](02-ecs-integration.md) (sync), [03](03-systems-and-update-loop.md) (full tick) |
| 0.5.0+ | `simple-movement`, … | [03](03-systems-and-update-loop.md) (input phase) |
| 0.7.0 | `particles` | [04](04-performance-considerations.md) |
| 0.9.0 | `physics-ball` | [02](02-ecs-integration.md) (sim authority), [03](03-systems-and-update-loop.md) (fixed step) |
| 0.8.0 | `debug-ui` | [06](06-ui-and-localization.md) (ImGui tier split) |
| 1.0.0 | `minimal-game` | Re-read 01–05 for API audit |
| 1.1.0+ | Crucible (Tier 3) | [06](06-ui-and-localization.md) (editor ImGui required) |
| 1.2.0 | i18n | [07](07-localization-system.md) (`LocalizationSystem`, `build.zig` pipeline) |
| 0.9.0 | `physics-ball` + resource reload | [08](08-hot-reload-nexus-engine.md) (resource hot reload) |
| 1.1.0+ | Crucible | [09](09-hot-reload-crucible.md) (editor-driven hot reload) |
| 1.1.0+ | Crucible mod UI | [13](13-wasm-modding.md) (WASM modding; editor abstraction layer) |

Optional background: [00b](00-legacy-node-scene-architecture.md) — Redot legacy tree (clean-room reference).
[13](13-wasm-modding.md) — WASM modding (stretch — post-1.0 context).

---

## Reading order (full ladder)

| # | File | What you learn |
| --- | --- | --- |
| 00 | **this file** | tiers, hybrid philosophy, release alignment |
| 00b | [`00-legacy-node-scene-architecture.md`](00-legacy-node-scene-architecture.md) | Redot legacy scene tree |
| 01 | [`01-scene-representation.md`](01-scene-representation.md) | `SceneNode` design; why hybrid |
| 02 | [`02-ecs-integration.md`](02-ecs-integration.md) | Flecs adapter; bridge sync |
| 03 | [`03-systems-and-update-loop.md`](03-systems-and-update-loop.md) | tick phases; node + ECS ordering |
| 04 | [`04-performance-considerations.md`](04-performance-considerations.md) | scaling; when to mirror |
| 05 | [`05-resource-and-asset-management.md`](05-resource-and-asset-management.md) | `Resource` vs zGameLib decode |
| 06 | [`06-ui-and-localization.md`](06-ui-and-localization.md) | Immediate-mode tools; batcher HUD |
| 07 | [`07-localization-system.md`](07-localization-system.md) | `LocalizationSystem`; PO→JSON in `build.zig` |
| 08 | [`08-hot-reload-nexus-engine.md`](08-hot-reload-nexus-engine.md) | Engine-level hot reload (resources, scenes, locale) |
| 09 | [`09-hot-reload-crucible.md`](09-hot-reload-crucible.md) | Editor-driven hot reload (file watcher, play-in-editor) |
| 10 | [`10-hazel-hazelnut-split.md`](10-hazel-hazelnut-split.md) | Hazel/Hazelnut split — lessons for our architecture |
| 11 | [`11-networking-decision.md`](11-networking-decision.md) | Networking decision — GNS vs ENet, full commitment to Valve GameNetworkingSockets |
| 12 | [`12-web-backend-strategy.md`](12-web-backend-strategy.md) | Web backend strategy — WebGPU for WASM (Tier 2 view) |
| 13 | [`13-wasm-modding.md`](13-wasm-modding.md) | WASM modding with editor-abstraction layer (Tier 2 runtime + Tier 3 tooling) |

**API reference:** [`../Nexus_Reference.md`](../Nexus_Reference.md)  
**Examples:** [`../examples/ladder.md`](../examples/ladder.md)  
**zGameLib foundation:** [upstream theory](https://github.com/SETA1609/zGameLib/tree/main/docs/theory)

---

## Bibliography

- **Nexus Engine Reference** — [`../Nexus_Reference.md`](../Nexus_Reference.md)
- **Roadmap** — [`../ROADMAP.md`](../ROADMAP.md)
- **zGameLib Reference** — upstream `docs/reference.md`
- **Redot layout** (study only) — behavior informs Nexus; code does not ship