# 13 — WASM modding with editor-abstraction layer

*How modding works across the three tiers: WASM sandbox at runtime, abstraction layer in Crucible.*

> **Release alignment:** WASM host API defined and mod loading **v1.0.0**; Crucible build/mod UI **v1.1.0+**; hot reload of WASM modules **post-1.1**.

---

## Why WASM for modding

WASM was chosen over Lua or native plugins because we already commit to it for Web deployment, gaining security and reuse at the cost of a higher entry barrier — which Crucible's tooling closes.

| Criterion | WASM | Lua |
|-----------|------|-----|
| Sandboxing | Strong (import-based) | Weak without heavy restrictions |
| Performance | Near-native | Good |
| Language flexibility | Rust, C, C++, Zig | Lua only |
| Reuse with Web target | Same technology | Separate |

Full comparison in the decision document below.

---

## Mod package structure

```ascii
mods/
└── my-mod/
    ├── mod.json          # metadata: name, version, author, dependencies
    ├── mod.wasm          # compiled logic (optional — data-only mods skip it)
    └── data/             # resource overrides, JSON/YAML configs
        ├── locale/
        └── scenes/
```

### `mod.json`

```json
{
  "id": "my-mod",
  "version": "1.0.0",
  "api_version": 1,
  "entry": "mod.wasm",
  "dependencies": [],
  "data_overrides": ["data/locale/en_overrides.po"]
}
```

---

## Tier responsibilities

| Tier | Owns | Details |
|------|------|---------|
| **zGameLib (T1)** | Nothing modding-specific | Stays lean — no modding logic |
| **Nexus Engine (T2)** | WASM runtime, host API, mod loading | `WasmHost`, `ModManager`, sandboxed execution |
| **Crucible (T3)** | Mod project templates, build abstraction | Compile orchestrator, hot reload UI, error display |

---

## Nexus Engine — WASM host

Nexus runs mods in a sandboxed WASM environment. The host exposes a curated **Mod API** — mods can only call what Nexus explicitly imports into the WASM module.

```zig
const WasmHost = struct {
    engine: *NexusEngine,

    pub fn loadMod(self: *WasmHost, path: []const u8) !*ModInstance {
        const bytes = try self.loadWasmFile(path);
        const module = try WasmModule.compile(bytes);
        const instance = try module.instantiate(.{
            .imports = &.{
                .{ "nexus", "log",     .func(wrapLog) },
                .{ "nexus", "spawn",   .func(wrapSpawn) },
                .{ "nexus", "get_node", .func(wrapGetNode) },
            },
        });
        // …
    }
};
```

### Phase 1: ModManager lifecycle

```ascii
ModManager
  ├── discover()        — scan mods/ directory, parse mod.json
  ├── load(id)          — instantiate WASM, call mod_init
  ├── unload(id)        — call mod_deinit, tear down
  ├── reload(id)        — unload + load (hot reload path)
  └── query_api(id)     — list exported functions
```

### Public Mod API surface

| Function | Purpose |
|----------|---------|
| `log(level, msg)` | Write to engine log with mod prefix |
| `spawn(resource_path)` | Spawn a scene/resource into the world |
| `get_node(path)` | Look up a SceneNode by path (read-only by default) |
| `set_property(path, key, value)` | Mutate a node property (sandboxed) |
| `on_tick(dt)` | Called every frame (if exported) |
| `on_event(event)` | Called on input or game events (if exported) |

Mods **cannot** access raw memory, call arbitrary native functions, or bypass the scene tree API.

---

## Crucible — editor abstraction layer

Crucible makes the WASM compilation pipeline invisible.

### Modder workflow

```ascii
1. Open Crucible
2. File → New Mod Project → choose template (Zig / Rust)
3. Write mod logic in Crucible's code editor (or external IDE)
4. Click "Build Mod" or press Ctrl+B
5. Crucible: compiles → packages → installs into project mods/
6. Click "Test Mod" → hot reloads into running game
7. Iterate
```

### Build orchestrator

```zig
// Pseudocode — Crucible mod build step
const ModBuildStep = struct {
    template: ModTemplate,
    source_dir: []const u8,
    output_dir: []const u8,

    pub fn build(self: *ModBuildStep) !void {
        // 1. Determine compiler from template type
        // 2. Spawn compiler subprocess
        //    - Zig:  zig build-lib -target wasm32-freestanding ...
        //    - Rust: cargo build --target wasm32-unknown-unknown ...
        // 3. Collect .wasm output
        // 4. Copy data files
        // 5. Write mod.json
        // 6. Copy to project mods/<name>/
    }
};
```

### Templates

Crucible ships curated project templates that include:
- A working build script pre-configured for WASM output
- The Mod API bindings (`.wasm` import stubs)
- A minimal `_init` / `_deinit` skeleton
- `mod.json` with correct defaults

Phase 1 ships templates for **Zig** and **Rust**. C/C++ can follow.

---

## Hot reload of WASM modules

Since WASM modules can be unloaded and reloaded at runtime (no leaky global state if the Mod API is designed cleanly), hot reload is a natural fit.

```ascii
Modder hits "Test Mod"
        │
        ▼
Crucible: rebuild .wasm
        │
        ▼
Crucible: EditorHost.reloadMod("my-mod")
        │
        ▼
Nexus: ModManager.reload("my-mod")
    ├── call mod_deinit on old instance
    ├── free WasmModule + instance
    ├── compile new .wasm
    ├── instantiate
    └── call mod_init on new instance
```

**Constraint:** Mods must be stateless across reload, or serialize/restore state from the Mod API. This mirrors Nexus's hot reload philosophy: data before code.

---

## Data-only mods

Not all mods need code. Mods that override locale strings, tweak damage tables, or replace textures can ship as `data/` files only — no `.wasm` entry required. Crucible's build UI distinguishes "code mod" vs "data mod" at project creation.

---

## Release alignment

| Version | Modding capability |
|---------|-------------------|
| **1.0.0** | WASM Host API defined + `ModManager` stub; mod loading from disk |
| **1.1.0+** | Crucible mod project templates, Build Mod button, basic hot reload |
| **Post-1.1** | Full hot reload, data-only mods, error display, mod publishing UI |

---

## Comparison with other engines

| Engine/Game | Modding approach | How we differ |
|-------------|-----------------|---------------|
| **Godot** | GDScript (no sandboxing) | WASM gives security, editor makes it easy |
| **Unity** | C# (full trust) | WASM sandbox prevents malicious mods |
| **Factorio** | Lua (sandboxed) | WASM gives more languages + better perf |
| **Minecraft (Forge)** | Java bytecode | WASM is better sandboxed + language-agnostic |
| **Bevy** | WASM (native) | Same direction — editor abstraction is our differentiator |

---

## Challenges

| Challenge | Mitigation |
|-----------|------------|
| Modders need to learn WASM-aware patterns | Templates + Mod API docs reduce the learning curve |
| Compilation is slow for large mods | Incremental builds, caching, clear feedback |
| Different languages → different toolchains | Ship Zig template first; Rust second; C/C++ third |
| Debugging WASM is harder than native script | Log API, structured error reporting, future debugger |

---

## Bibliography

- **Nexus hot reload** — [08-hot-reload-nexus-engine.md](08-hot-reload-nexus-engine.md) (event bus applies to WASM reload too)
- **Web deployment** — [12-web-backend-strategy.md](12-web-backend-strategy.md) (WASM + WebGPU)
- **WASI / WASM spec** — [WebAssembly.org](https://webassembly.org/)
- **Bevy WASM modding** — [Bevy Modding RFC](https://github.com/bevyengine/bevy/discussions/10861)
- **Factorio modding (Lua sandbox)** — [Factorio API docs](https://lua-api.factorio.com/)
