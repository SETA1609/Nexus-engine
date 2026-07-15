# Crucible — Tier 3 editor (documentation)

> **Official name:** **Crucible** (alias: *Link-editor*).  
> **Status:** Planned — ships with Nexus **v1.1.0+**.  
> **Repository:** Documentation lives **here** in `Nexus-engine` for now. A separate
> `Crucible` git repository may be created later; the `EditorHost` API stays in Nexus.

Crucible is the **detachable editor** for Nexus. It edits the `SceneNode` hierarchy, inspects
ECS state via `EditorHost` (never direct Flecs linkage in the preferred layout), and uses
**Dear ImGui** for all tool UI.

---

## UI model

- **Opinionated immediate mode** (Casey Muratori / Handmade Hero style) — panels rebuilt each frame.
- **Not** the in-game UI stack. Game HUDs use Nexus `Control` nodes + zGameLib **2D batcher**.

See [`../theory/06-ui-and-localization.md`](../theory/06-ui-and-localization.md) and
[`../Nexus_Reference.md`](../Nexus_Reference.md) §9 (EditorHost) and §13 (UI strategy).

---

## Dependencies

| Needs | From |
|-------|------|
| `EditorHost`, `SceneTree`, scene mutation API | Nexus (Tier 2) |
| `zgame.zimgui` (`-DimGui=true`) | zGameLib — **late** optional module |
| Flecs types | **Avoid** — use `EditorHost.getEcsComponents` |

---

## Roadmap

| Nexus version | Crucible milestone |
|---------------|-------------------|
| **1.0.0** | `EditorHost` API frozen in Nexus |
| **1.1.0+** | Scene tree, inspector, viewport, play mode |
| **1.2.0+** | `.po` editing workflow (localization stays runtime in Nexus) |

Full plan: [`../ROADMAP.md`](../ROADMAP.md) § v1.1.0+.

---

## Comparison

| Engine | Editor | Crucible |
|--------|--------|----------|
| Godot | Monolithic, custom retained UI | Detached binary, Dear ImGui |
| Unity | External (Editor) | Same separation goal |
| Unreal | Slate-based | Lighter — ImGui only for tools |