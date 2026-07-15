# Mission — Nexus examples

> Concrete commitments for the example ladder: how each app is built, what hybrid
> behavior it must demonstrate, and what "green" means.

## What we will build

1. **One or two examples per minor release** (see [`../ROADMAP.md`](../ROADMAP.md)), each with a design doc in `docs/examples/` and source in `examples/`.

2. **Examples consume `nexus` + `zgame`** — same as a real game. `main.zig` in an example is thin; logic demonstrates engine APIs.

3. **Hybrid rules enforced by the ladder:**
   - v0.1.0–0.2.0: **SceneNode only** — no Flecs in public example code.
   - v0.3.0+: ECS behind `EcsBridge` — no `#include flecs.h` in examples.
   - v0.7.0 `particles`: **ECS-only** sim entities — spawner is a single `SceneNode`.

4. **API-first + TDD** — contract tests land with the version that introduces an API; examples land in the same tag.

5. **CI** — `zig build <example>` for each shipped rung; `zig build run` where display available (dummy `RenderingServer` for headless).

6. **Documentation per example** — What it does · What it forces into existence · Frame loop pseudocode · Hybrid takeaway.

## What "green" means

- Example **builds and runs** on Linux + Windows (macOS: contributor-verified runtime).
- Uses **documented public API** only — no engine internals.
- Design doc matches source for the tagged version.
- Reader can copy the pattern into their own game.

## Non-goals

- Shared example framework across apps — duplication is fine.
- Testing zGameLib in isolation — use zGameLib's own ladder for that.
- Crucible workflows — Tier 3 examples live in the editor repo later.

## See also

[`vision.md`](vision.md) · [`ladder.md`](ladder.md) · [`../ROADMAP.md`](../ROADMAP.md)