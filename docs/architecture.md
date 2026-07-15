# Nexus Engine — Architecture

## A Tier 2 Engine on zGameLib

Nexus Engine is a **Tier 2 game engine** built on top of the **zGameLib** framework (Tier 1). It provides higher-level game systems — scene graph, servers, resource management, scripting — while keeping raw access to the foundation beneath.

It follows the same **3-handshake model** as the framework it consumes:

```
┌──────────────────────────────────────────────────────────────┐
│  TIER 3: EDITOR (Human + Scripting Layer)                    │
│    • Visual inspection of what the code does                 │
│    • Scripting (Mono/C# or native Zig)                       │
│    • Optional — many projects ship without it                │
└───────────────────────────────┬──────────────────────────────┘
                                │ uses / extends
┌───────────────────────────────▼──────────────────────────────┐
│  TIER 2: NEXUS ENGINE (Abstraction Layer)                    │
│    • Higher-level game systems (scene, servers, resources)   │
│    • Built on top of zGameLib APIs                           │
│    • No editor required to ship games                        │
│    • One possible consumer of the framework                  │
└───────────────────────────────┬──────────────────────────────┘
                                │ uses or re-exports
┌───────────────────────────────▼──────────────────────────────┐
│  TIER 1: zGAMELIB FRAMEWORK (Foundation — raylib-like)       │
│    • Direct game development (like raylib)                   │
│    • Raw access to platform, Vulkan, audio, assets, math     │
│    • Transparent — every layer re-exports the one below      │
│    • Can be used standalone to ship complete games           │
└──────────────────────────────────────────────────────────────┘
```

### Key insight
The engine is **just another consumer** of zGameLib. It can re-export zGameLib's APIs, wrap them, or bypass them entirely when raw access is needed.

---

## Design Principles

### Raw-First & Transparent
Every engine convenience layer is built on raw zGameLib APIs that remain fully reachable. You never get stuck.

### Servers over Monoliths
Engine subsystems (rendering, audio, physics, scripting) follow the server pattern — independent, swappable, communicating through narrow seams.

### Explicit over Implicit
Following zGameLib's lead: Vulkan is the primary graphics path, control is always explicit.

---

## Dependency Graph

```
┌────────────────────────────────────────┐
│  Nexus Engine (Tier 2)                 │
│  • scene graph                         │
│  • servers (render, audio, physics)    │
│  • resource management                 │
│  • scripting integration               │
├────────────────────────────────────────┤
│  zGameLib (Tier 1)                     │
│  • platform (SDL3)                     │
│  • vulkan (vk + volk + VMA + shaderc) │
│  • surface bridge + swapchain          │
│  • Gpu · FrameRing · App               │
│  • animation (zClip)                   │
├────────────────────────────────────────┤
│  Sibling Libraries                     │
│  • platform adapter (windowing/input)  │
│  • vulkan stack adapter                │
│  • zClip (animation)                   │
│  • (future: audio, assets, math)       │
└────────────────────────────────────────┘
```

The engine links `zgame` which transitively links only the sibling libraries it uses.

---

## Current State

This engine is in early development. The foundation is wired:
- zGameLib dependency via local path in `build.zig.zon`
- `zgame` module imported in the engine root
- Platform initialisation + Vulkan window at startup

Next rungs will add engine-specific systems on top of zGameLib's building blocks.
