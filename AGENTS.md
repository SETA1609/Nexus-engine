# Nexus-engine — agent instructions

## Build & run

```sh
zig build                 # compile → zig-out/bin/nexus-engine
zig build run             # build + run (needs display + Vulkan loader)
zig build -Doptimize=ReleaseFast
```

Requires Zig 0.16+ (pinned in CI: `mlugg/setup-zig@v2` with `version: 0.16.0`).

## Dependency: zGameLib

The only dependency is `zgame` via local path `../zGameLib` in `build.zig.zon`.
The sibling repo must exist at that path. zGameLib itself has git submodules that must be initialized:

```sh
cd ../zGameLib && git submodule update --init --recursive
```

## Architecture

- **Tier 2: Nexus Engine** (alias: *Forge*). **Tier 3: Link-editor** (alias: *Crucible*). Tier 2 consumes zGameLib (Tier 1). Single executable, no library output.
- Docs: `docs/Nexus_Reference.md`, `docs/theory/` (01–05), `docs/file-tree.yml`, `docs/dependencies.yml` (zGameLib — `../zGameLib/docs/{file-tree,dependencies}.yml`).
- Entrypoint: `src/main.zig` — imports `zgame`, inits platform, creates Vulkan window, event loop.
- All zGameLib APIs reachable: `zgame.platform`, `zgame.vk`, `zgame.Gpu`, `zgame.FrameRing`, etc.
- C/C++ source dirs (`src/c/`, `src/cpp/`) are leftovers from the template — **not compiled** by current `build.zig`.

## Tests

None exist. No `zig build test` step. Add tests via `b.addTest(...)` in `build.zig` when needed.

## CI

Single workflow (`.github/workflows/build.yml`): `zig build` + `zig build run` on ubuntu/macos/windows. The `run` step requires a display — will fail in headless CI. **macOS is in scope** (Redot-informed platform path): CI runs builds in VM pipelines; contributors validate windowed runtime on real Mac hardware before macOS-specific changes land.

## Stale docs

`README.md` still describes the old cpp-zig-hybrid-template. The source of truth for the current engine is `docs/Nexus_Reference.md`, `docs/theory/`, and `build.zig`.
