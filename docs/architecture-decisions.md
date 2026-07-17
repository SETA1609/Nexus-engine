# Architecture Decisions — Nexus Engine

## 1. Static library host + reloadable game logic

Nexus ships as a **static library** (`libnexus-engine.a`). It is the stable host —
never reloaded at runtime. Game logic lives in a separate shared library
(future `build-plugin` step).

This follows TheCherno's Hazel/Hazelnut pattern (engine core as `.a`, separate
consumers) and Casey Muratori's platform/game DLL split.

- The engine **never contains game logic** — that is the rule enabling hot reload.
- `createEngineInterface()` is exported as a C-ABI symbol so the editor discovers
  it via `@extern` at link time — no direct source dependency.
- Full strategy: [`docs/theory/08-hot-reload-nexus-engine.md`](theory/08-hot-reload-nexus-engine.md)
- Bundle-level rationale: [`../docs/architecture-decisions.md`](../../docs/architecture-decisions.md)

## 2. Script encapsulation for CI

No non-trivial bash/Python inline in `.github/workflows/*.yml`. All meaningful
logic goes in `scripts/` and is called from CI.

**Example:** `.github/workflows/build.yml` calls `python3 scripts/validate-workflows.py`
instead of inlining the Python. The same script is usable locally.

See `scripts/validate-workflows.py` · `scripts/build-in-docker.sh`
