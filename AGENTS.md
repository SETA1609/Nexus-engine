# Nexus-engine — agent instructions

## Build & run

```sh
zig build                 # compile (default: pipeline)
zig build run             # build + run (needs display + Vulkan loader)
zig build -Doptimize=ReleaseFast
```

Requires Zig **0.16.0**.

## Docker development

```sh
./scripts/build-in-docker.sh            # `zig build pipeline` in Docker
./scripts/build-in-docker.sh build-lib  # static lib only
./scripts/build-in-docker.sh run        # run in Docker (needs display)
./scripts/shell.sh                      # interactive container shell
./scripts/clean.sh                      # remove volumes + build artifacts
```

## Dependency: zGameLib

The only dependency is `zgame` via `libs/zGameLib` — a Git submodule in `libs/`.
After cloning this repo, initialize submodules:

```sh
git submodule update --init --recursive
```

## Architecture

- **Tier 2: Nexus Engine** (alias: *Forge*). **Tier 3: Link-editor** (alias: *Crucible*). Tier 2 consumes zGameLib (Tier 1). Single executable, no library output.
- **EngineInterface contract** defined in `contract/engine_interface.zig` (root bundle). Nexus implements it via `createEngineInterface()` in `src/root.zig`. The editor consumes the interface instead of importing Nexus modules directly.
- Docs: `docs/Nexus_Reference.md`, `docs/theory/` (01–05), `docs/file-tree.yml`, `docs/dependencies.yml` (zGameLib — `../zGameLib/docs/{file-tree,dependencies}.yml`).
- Entrypoint: `src/root.zig` — exports `NexusApp` for consumers; runtime entry in `src/runtime/main.zig`.
- All zGameLib APIs reachable: `zgame.platform`, `zgame.vk`, `zgame.Gpu`, `zgame.FrameRing`, etc.
- C/C++ source dirs (`src/c/`, `src/cpp/`) are leftovers from the template — **not compiled** by current `build.zig`.

## Tests

None exist. No `zig build test` step. Add tests via `b.addTest(...)` in `build.zig` when needed.

## CI

Reusable workflow: `.github/workflows/reusable/build.yml`.
Main CI: `.github/workflows/build.yml` — cross-platform pipeline build via reusable workflow.
