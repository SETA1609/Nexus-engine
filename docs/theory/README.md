# The theory of Nexus Engine — a reading path

> **Naming:** **Nexus Engine** (Tier 2, this repo) — *Forge* is an alias.
> **Link-editor** (Tier 3) — *Crucible* is an alias.

This folder explains **why and how** the Nexus Engine layer (Tier 2) is shaped:
the hybrid SceneNode + ECS model, the update loop, performance trade-offs, and
where Nexus Engine ends and zGameLib (Tier 1) begins.

It assumes you can open a window with zGameLib (see the upstream
[`docs/theory/`](https://github.com/SETA1609/zGameLib/tree/main/docs/theory) ladder
for Tier 1). You do **not** need to read every zGameLib source file first — each
chapter here states what it borrows from Tier 1.

---

## The mental model: three tiers, one boundary

Nexus Engine is not "zGameLib plus some helpers." It is a **game engine**: scene
representation, servers, resources, and a main loop that coordinates them.

```ascii
┌─────────────────────────────────────────────────────────────────┐
│  LINK-EDITOR (Tier 3) — edits SceneNodes, inspects ECS via Nexus Engine     │
├─────────────────────────────────────────────────────────────────┤
│  NEXUS ENGINE (Tier 2) — THIS DOCUMENTATION                            │
│    SceneTree · EcsBridge · Servers · Resources · NexusApp       │
├─────────────────────────────────────────────────────────────────┤
│  zGAMELIB (Tier 1) — platform · Vulkan · decode · audio · math  │
└─────────────────────────────────────────────────────────────────┘
```

**Golden rule (inherited from zGameLib):** raw-first / opt-in. Nexus Engine wraps
zGameLib; it does not replace it. Drop to `zgame.vk` whenever a server is in
your way.

**Nexus-specific rule:** hybrid-by-default. SceneNodes are the authoring and
scripting surface; ECS is the optional performance plane behind an explicit bridge.

---

## Why hybrid? (one paragraph)

Redot and Godot proved that a **retained node tree** is unmatched for editor
workflows, scene serialization, and beginner mental models. They also showed the
cost: thousands of `_process` callbacks and deep hierarchy updates do not scale
like data-oriented systems. Nexus Engine keeps the tree for **structure and UX**, and
adds an **optional ECS mirror** for subsystems that benefit from bulk iteration
(physics, culling, particles). You pay for ECS complexity only where you opt in.

---

## Reading order

Read in this order — each file builds on the last:

| # | File | What you learn |
| --- | --- | --- |
| 00 | **this file** | tiers, hybrid philosophy, reading path |
| 00b | [`00-legacy-node-scene-architecture.md`](00-legacy-node-scene-architecture.md) | Redot legacy scene tree (the "before" picture) |
| 01 | [`01-scene-representation.md`](01-scene-representation.md) | `SceneNode` design; tree vs pure ECS vs hybrid |
| 02 | [`02-ecs-integration.md`](02-ecs-integration.md) | Flecs adapter; bridge sync; when to mirror |
| 03 | [`03-systems-and-update-loop.md`](03-systems-and-update-loop.md) | tick phases; node traversal + ECS systems |
| 04 | [`04-performance-considerations.md`](04-performance-considerations.md) | expected scaling; pitfalls; profiling |
| 05 | [`05-resource-and-asset-management.md`](05-resource-and-asset-management.md) | `Resource` vs zGameLib decode; UID; packs |

**Companion reference:** [`../Nexus_Reference.md`](../Nexus_Reference.md) — the
single-page map of all Nexus Engine components.

**Upstream foundation:** [zGameLib theory](https://github.com/SETA1609/zGameLib/tree/main/docs/theory) (files 01–07).

---

## Bibliography

- **Nexus Engine Reference** — [`../Nexus_Reference.md`](../Nexus_Reference.md)
- **zGameLib Reference** — upstream `docs/reference.md`
- **Redot engine layout** (study only) — `core/`, `scene/`, `servers/`, `editor/` in the Redot fork; behavior informs Nexus Engine, code does not ship