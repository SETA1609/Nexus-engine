# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Nexus Engine (repo `Nexus-engine`, alias *Forge*) is **Tier 2** of a 3-tier bundle:
zGameLib (T1, foundation) → **Nexus (T2, this repo)** → Link-editor (T3, *Crucible*).
It is a Zig codebase requiring **Zig 0.16.0** (pinned; the build APIs used are 0.16-only).

> `AGENTS.md` is the per-tier source of truth — read it alongside this file. `docs/architecture.md`,
> `docs/Nexus_Reference.md`, and `docs/theory/` (01–05) carry the design rationale.

## Build & run

```sh
zig build                 # default step = "pipeline": builds static lib + runtime
zig build build-lib       # static lib only  -> libnexus-engine.a
zig build build-runtime   # no-editor runtime exe (depends on the lib)
zig build build-engine    # both paths, no run
zig build run             # build + run nexus-runtime (needs display + Vulkan loader)
zig build -Doptimize=ReleaseFast   # (also ReleaseSafe / ReleaseSmall)
zig build -Dtarget=x86_64-windows  # cross-compile
```

First-time / after clone — the only dependency, `zgame`, is a **git submodule** at
`libs/zGameLib` (see `build.zig.zon`), so init submodules or nothing builds:

```sh
git submodule update --init --recursive
```

Docker (Ubuntu + Zig 0.16 + Vulkan/xvfb, from `docker/Dockerfile`):

```sh
./scripts/build-in-docker.sh [pipeline|build-lib|build-runtime|run]  # inits submodules, then zig build
./scripts/shell.sh          # interactive container shell
./scripts/clean.sh          # remove volumes + build artifacts
```

**Artifacts:** a plain `zig build` installs to `zig-out/{lib,bin}` (`libnexus-engine.a`,
`nexus-runtime`). The `build/` mirror referenced in `build.zig`/`AGENTS.md` comments is the
prefix used by the bundle/Docker orchestration one level up, not by a bare `zig build` here.
Both `build/` and `zig-out/` are gitignored.

**Tests:** none exist — there is no `zig build test` step. Add one via `b.addTest(...)` in
`build.zig` if you introduce tests. Do not assume a test command works.

## Architecture

Two-path build (Cherno/Hazel-style core-vs-runtime split), both defined in `build.zig`:

- **Path 1 — static library** `libnexus-engine.a`, built from the `nexus` module
  (`src/root.zig`). This is the engine core; it contains **no editor code** and is
  consumed by the runtime, the editor, and games alike.
- **Path 2 — runtime executable** `nexus-runtime` (`src/runtime/main.zig`): a thin
  entry point that imports the `nexus` module and links the static lib. No ImGui, no
  editor panels — it is the "game ships without the editor" consumer. `zig build run`
  runs *this*, never an editor.

**Public API (`src/root.zig`).** Exports `NexusApp` (window lifecycle: `init`/`deinit`/
`shouldClose`/`tick`, currently a Vulkan window over zGameLib `platform`). All of zGameLib
is reachable through the `zgame` import (`zgame.platform`, `zgame.vk`, `zgame.Gpu`,
`zgame.FrameRing`, …); Nexus is "just another consumer" of zGameLib and game code may call
`zgame.*` directly.

**EngineInterface contract.** The contract lives at `../contract/engine_interface.zig`
(bundle root) and is wired in as the `engine_interface` module in `build.zig`. The editor
depends on this **engine-agnostic vtable**, not on Nexus modules. `src/root.zig` implements
it: `createEngineInterface()` is an `export fn` (stable C-ABI symbol) that heap-allocates a
`NexusApp` and returns an `EngineInterface.wrap(...)` whose vtable forwards to the
`nexus*` free functions. The editor discovers this symbol via the linked static lib —
no direct module import. When you change the vtable, update both the contract file and the
`nexus*` adapters here.

**Planned (not yet in code):** SceneNode tree, optional ECS (Flecs adapter), servers/
resources, hot-reload — see `docs/architecture.md` and `docs/ROADMAP.md`. The interface
reserves capability flags / `getNexusApi` for these; today `NexusApp` is minimal.

## Gotchas

- **`src/c/` and `src/cpp/` are dead template leftovers** (`greetFromC.c`,
  `greetFromCpp.cpp`). `build.zig` compiles **only Zig** — it has no `addCSourceFiles`
  call — so these are never built (though `build.zig.zon` `.paths` ships the whole `src/`).
- **`README.md` is stale** — it is the original `cpp-zig-hybrid-template` README and does
  **not** describe Nexus. Trust `AGENTS.md` and `docs/` instead. `cheat_sheet.md` is a
  generic Zig-vs-C/C++ / Zig-0.16 field guide and is genuinely useful.
- Zig is pre-1.0; build APIs moved in 0.15→0.16 (C sources/libc on Modules, `Io` interface,
  unmanaged `ArrayList`). Stay on 0.16.0.
