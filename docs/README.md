# Nexus Engine Docs

This repository (**Nexus-engine**) is **Nexus Engine** (Tier 2). *Forge* is an
alias for the same engine — use either name; docs standardize on **Nexus Engine**.

3-tier stack: zGameLib → Nexus Engine → Link-editor (*Crucible* is an alias).

| Document | What it covers |
|----------|---------------|
| [`Nexus_Reference.md`](Nexus_Reference.md) | Authoritative Tier 2 reference: hybrid SceneNode + ECS, servers, EditorHost |
| [`architecture.md`](architecture.md) | Short stack overview and dependency graph |
| [`getting-started.md`](getting-started.md) | Build, run, extend |
| [`theory/README.md`](theory/README.md) | Incremental theory ladder (read 01 → 05) |

### Theory ladder (Nexus-specific)

| # | File | Topic |
|---|------|-------|
| 01 | [`theory/01-scene-representation.md`](theory/01-scene-representation.md) | SceneNode hierarchy; why hybrid |
| 02 | [`theory/02-ecs-integration.md`](theory/02-ecs-integration.md) | Flecs bridge; sync policies |
| 03 | [`theory/03-systems-and-update-loop.md`](theory/03-systems-and-update-loop.md) | Main loop phases |
| 04 | [`theory/04-performance-considerations.md`](theory/04-performance-considerations.md) | Scaling vs pure nodes |
| 05 | [`theory/05-resource-and-asset-management.md`](theory/05-resource-and-asset-management.md) | Resources vs zGameLib decode |

**Tier 1 foundation:** [zGameLib docs](https://github.com/SETA1609/zGameLib/tree/main/docs) (reference + theory 01–07).

**Tier 3 editor:** Link-editor (detachable; consumes `EditorHost` from Nexus Engine).
*Crucible* is an alias.