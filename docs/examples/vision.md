# Vision — Nexus example ladder

> Small, runnable apps that prove **Tier 2** (Nexus Engine) on **Tier 1** (zGameLib):
> hybrid SceneNode + optional ECS, explicit servers, raw `zgame.*` still reachable.

## North star

A green ladder is proof that:

- Games can ship with **nodes alone** for early versions.
- **ECS complexity is opt-in** — introduced at v0.3.0, sync at v0.4.0, heat at v0.7.0.
- **Crucible is not required** until Tier 3 (v1.1.0+).

```ascii
zGameLib examples          Nexus examples              Crucible
(event-logger …)    →    (clear-color … minimal-game)  →  (editor)
Tier 1 ladder            Tier 2 ladder                 Tier 3
```

## Hybrid story the ladder tells

| Act | Versions | User learns |
|-----|----------|-------------|
| **I — Engine boot** | 0.1.0 | `NexusApp.tick()` replaces hand-rolled `main` |
| **II — Retained scene** | 0.2.0 | Scene tree is the authoring model |
| **III — ECS appears** | 0.3.0–0.4.0 | Mirror + sync; not a replacement for nodes |
| **IV — Gameplay** | 0.5.0–0.6.0 | Input, camera — still node-centric API |
| **V — Performance** | 0.7.0–0.8.0 | ECS-only particles; measure bridge cost |
| **VI — Sim + ship** | 0.9.0–1.0.0 | Physics + alpha game |

## Non-vision

- A second game engine inside examples — they call `nexus.*`, not reimplement servers.
- Full Godot/Redot parity — clean-room, incremental.
- Baked-in Dear ImGui editor — `debug-ui` is dev overlay only; Crucible is Tier 3.

## See also

[`mission.md`](mission.md) · [`ladder.md`](ladder.md) · [`../theory/README.md`](../theory/README.md)