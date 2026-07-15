# Theory: Web Backend Strategy – WebGPU for WASM (Tier 2 View)

## Purpose

This document covers what **Nexus-engine** needs to do for web deployment via WASM + WebGPU. The low-level WebGPU backend implementation lives in **zGameLib** as an optional sibling module — see the zGameLib theory doc
[10-web-backend-strategy.md](../../../libs/zGameLib/docs/theory/10-web-backend-strategy.md) for the Tier 1 details. This doc focuses on the engine layer.

## 1. Background

- We deprecated OpenGL in zGameLib.
- WebGL is based on OpenGL ES — supporting it contradicts that decision.
- **WebGPU** is the modern, explicit, Vulkan-aligned web graphics API.
- zGameLib provides the WebGPU backend (device, queue, swapchain, command buffers) as an optional module.

## 2. Division of Responsibility

| Tier | What it owns | Example files / modules |
|------|-------------|------------------------|
| **zGameLib (Tier 1)** | WebGPU backend: device, surface, swapchain, pipelines, bind groups, command buffers, WGSL compilation | `zgame.webgpu.*` |
| **Nexus-engine (Tier 2)** | Scene rendering on WebGPU, material system, shader management, post-processing, lighting, particles, web-specific game systems | `src/web/`, scene renderer |
| **Crucible (Tier 3)** | Editor tooling for web build targets, deploy config | Future |

## 3. What Lives in Nexus-engine

- **Scene rendering logic** wired to WebGPU
  - SceneNode rendering through the WebGPU backend
  - Camera systems, culling
- **Material & shader system**
  - Material definitions
  - Shader compilation (WGSL) and hot-reloading
  - Material instances
- **High-level rendering features**
  - Post-processing
  - Particle systems
  - Lighting
- **Web-specific game systems**
  - Web input handling (touch, gamepad via browser APIs)
  - Web asset loading (fetch, streaming)

## 4. Implementation Strategy

The engine follows zGameLib's incremental backend bring-up:

| Phase | Nexus-engine Task                              | Depends on zGameLib |
|-------|-----------------------------------------------|---------------------|
| 1     | — (zGameLib basic WebGPU bring-up)            | Phase 1             |
| 2     | — (zGameLib 2D batcher parity)                | Phase 2             |
| 3     | Wire scene rendering to WebGPU backend        | Phase 1-2           |
| 4     | Web input, asset loading, platform glue       | Phase 3             |

Nexus-engine should not start Phase 3 until zGameLib's WebGPU backend is stable for basic 2D rendering.

## 5. References

- **zGameLib WebGPU backend plan**: [10-web-backend-strategy.md](../../../libs/zGameLib/docs/theory/10-web-backend-strategy.md)
- **WebGPU Specification**: https://gpuweb.github.io/gpuweb/
- **WebGPU Samples**: https://webgpu.github.io/webgpu-samples/

---

*Document created: 2026-07-15. Companion to zGameLib theory 10-web-backend-strategy.md.*
