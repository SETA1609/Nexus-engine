# Getting Started — Nexus Engine

This repo (**Nexus-engine**) is the Tier 2 engine. **Nexus Engine** is the canonical
name; **Forge** is an alias for the same project. See
[`Nexus_Reference.md`](Nexus_Reference.md) and [`theory/README.md`](theory/README.md)
for architecture before extending code.

## Prerequisites

- **Zig 0.16+**
- A display server + Vulkan loader (for windowed / GPU examples)
- The zGameLib repo at `../zGameLib` (relative to the engine root)

## Build & Run

```sh
git clone <engine-url>
cd Nexus-engine
zig build                 # compile the engine binary
zig build run             # build + run (opens a Vulkan window)
```

The binary lands at `zig-out/bin/nexus-engine`.

## Project Layout

```
├── build.zig             # build script — consumes zgame module
├── build.zig.zon         # dependency manifest (zgame via local path)
├── src/
│   ├── main.zig          # engine entry point
│   ├── c/                # engine-native C sources (optional)
│   └── cpp/              # engine-native C++ sources (optional)
└── docs/
    ├── Nexus_Reference.md  # Tier 2 authoritative reference
    ├── architecture.md     # short stack overview
    ├── theory/             # incremental docs (01–05)
    └── getting-started.md  # this file
```

## Extending

The engine imports the full `zgame` module. You can reach everything directly:

```zig
const zgame = @import("zgame");
const platform = zgame.platform;
const vk = zgame.vk;

// Raw Vulkan, platform, surface, swapchain, FrameRing, Gpu, etc.
// All available through the one `zgame` import.
```

For the framework's full API surface, see the [zGameLib reference](https://github.com/SETA1609/zGameLib).
