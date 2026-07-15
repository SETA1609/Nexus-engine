# The theory of Nexus Engine — a reading path

> **Naming:** **Nexus Engine** (Tier 2, this repo) — *Forge* is an alias.
> **Link-editor** (Tier 3) — *Crucible* is an alias.

This folder explains **why and how** the hybrid engine is shaped: retained
`SceneNode` hierarchy + optional ECS bridge, update loop, performance trade-offs,
and Tier 1 ↔ Tier 2 boundaries.

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

**Nexus rule:** hybrid-by-default — nodes for authoring; ECS for heat behind `EcsBridge`.

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
| 1.2.0 | i18n | [06](06-ui-and-localization.md) (`LocalizationSystem`, `.po`→JSON) |

Optional background: [00b](00-legacy-node-scene-architecture.md) — Redot legacy tree (clean-room reference).

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
| 06 | [`06-ui-and-localization.md`](06-ui-and-localization.md) | Immediate-mode tools; batcher HUD; `LocalizationSystem` |

**API reference:** [`../Nexus_Reference.md`](../Nexus_Reference.md)  
**Examples:** [`../examples/ladder.md`](../examples/ladder.md)  
**zGameLib foundation:** [upstream theory](https://github.com/SETA1609/zGameLib/tree/main/docs/theory)

---

## Bibliography

- **Nexus Engine Reference** — [`../Nexus_Reference.md`](../Nexus_Reference.md)
- **Roadmap** — [`../ROADMAP.md`](../ROADMAP.md)
- **zGameLib Reference** — upstream `docs/reference.md`
- **Redot layout** (study only) — behavior informs Nexus; code does not ship