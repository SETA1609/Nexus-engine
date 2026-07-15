# Theory: The Cherno's Hazel & Hazelnut Split — Lessons for Our Architecture

## Introduction

Yan Chernikov (The Cherno) built **Hazel** as both a learning project and a real game engine through his long-running YouTube series. One of the most important architectural decisions he made was separating the **engine** from the **editor**.

- **Hazel** = The core engine (runtime systems, rendering, scene management, etc.)
- **Hazelnut** = The editor application (level editor, tools, UI)

This separation is highly relevant to our own 3-tier architecture:
- **zGameLib** (Tier 1 — Foundation)
- **Nexus-engine** (Tier 2 — Engine)
- **Crucible** (Tier 3 — Editor)

## How The Cherno Did the Split

### Early Phase (2019–2020)
In the beginning of the series, everything was developed together. Hazelnut started as a folder inside the Hazel project called `Hazelnut/`.

Key early video:
- **"Scene Hierarchy Panel | Game Engine series"** (August 2020)
  - He explicitly says Hazelnut is the level editor.
  - He creates panels (Scene Hierarchy, Inspector, etc.) inside the Hazelnut project.
  - Link: https://www.youtube.com/watch?v=wziDnE8guvI

At this stage, the editor was already somewhat separated in folder structure, but still compiled as part of the same solution.

### Later Phase (2023+)
By the time Hazel reached more mature releases (Hazel 2023.1 and beyond), the separation became cleaner:

- **Hazel** is treated as a library/engine that can be used independently.
- **Hazelnut** is the standalone editor application that links against Hazel.
- There is a clear distinction between:
  - Runtime game code
  - Editor-only code (ImGui panels, docking, content browser, etc.)

Relevant video:
- **"From Editor to Runtime - The Hazel Engine Workflow"** (Feb 2024)
  - Excellent explanation of the workflow between Hazelnut (editor) and the runtime.
  - Shows how projects are created, edited in Hazelnut, and then run.
  - Link: https://www.youtube.com/watch?v=Z2U-S3fxAg8

### Key Architectural Decisions The Cherno Made

1. **Editor as a Separate Application**
   - Hazelnut is a full executable that links to Hazel as a library.
   - This allows Hazel to be used without the editor (important for runtime/distribution).

2. **Heavy Use of ImGui in the Editor**
   - Almost all editor UI is built with Dear ImGui.
   - This made the editor relatively fast to develop and iterate on.

3. **Scene as the Central Abstraction**
   - Both editor and runtime work with the same `Scene` concept.
   - The editor can play the scene in-editor (similar to Unity Play Mode).

4. **Clear Separation of Concerns**
   - Engine = Core systems (Renderer, Scene, Components, Physics, etc.)
   - Editor = Tools, UI panels, Content Browser, Inspector, Viewport, etc.

## How We Can Apply This to Our Project

Our goal is to build a **modular, modern, and explicit** engine. We can learn from The Cherno while improving on some aspects.

### Recommended Structure for Us

```ascii
Crucible (Editor Application)
    ├── Uses Dear ImGui (like Hazelnut)
    ├── Scene editing, Inspector, Hierarchy, etc.
    └── Links against Nexus-engine as a library
           │
           ▼
Nexus-engine (Engine Library)
    ├── Hybrid SceneNode + ECS (Flecs first)
    ├── LocalizationSystem (data-oriented)
    ├── Can run standalone (runtime)
    └── No editor-specific code
           │
           ▼
zGameLib (Foundation Library)
    ├── Vulkan, SDL3, 2D batcher, optional modules (ImGui, future fonts)
    └── Pure low-level reusable foundation
```

### Key Lessons We Should Take

| Lesson from The Cherno              | How We Should Apply It                              | Improvement We Can Make |
|-------------------------------------|-----------------------------------------------------|-------------------------|
| Editor as separate application      | Crucible should be a separate executable            | Plan this separation from the beginning (he did it late) |
| Heavy ImGui usage in editor         | Use Dear ImGui in Crucible                          | Make ImGui optional in zGameLib (we already decided this) |
| Scene as central concept            | Use SceneNode + optional ECS link                   | Make it more data-oriented than his component system |
| Runtime should work without editor  | Nexus-engine must be usable standalone              | Stronger emphasis on this from day one |
| Clear module boundaries             | Strict separation between zGameLib / Nexus / Crucible | More explicit than his structure |

### What We Can Do Better

- **Plan the split early** — The Cherno refactored late, which made things harder.
- **Make zGameLib truly reusable** — Even Hazel's lower layers were quite engine-specific. We want zGameLib to be usable by other engines too.
- **Data-oriented localization & systems** — His component model was more traditional OOP. We are aiming for more data-oriented design.
- **Hot reloading strategy** — We should design hot reloading (especially data) more intentionally from the start.

## Recommended Resources & References

### Primary Videos from The Cherno

1. **"From Editor to Runtime - The Hazel Engine Workflow"** (Feb 2024)
   - Best current overview of how Hazelnut and Hazel work together.
   - https://www.youtube.com/watch?v=Z2U-S3fxAg8

2. **"Scene Hierarchy Panel | Game Engine series"** (Aug 2020)
   - Early explanation of Hazelnut as the level editor.
   - https://www.youtube.com/watch?v=wziDnE8guvI

3. **Hazel 2023.1 Release Video**
   - Shows the state of the engine and editor after significant development.
   - https://www.youtube.com/watch?v=L_XLGmG2Ct8

### GitHub Repository

- **TheCherno/Hazel** (main repository containing both Hazel and Hazelnut)
  - https://github.com/TheCherno/Hazel

### Additional References

- Hazel Official Website: https://hazelengine.com
- Hazel Documentation: https://docs.hazelengine.com

## Conclusion

The Cherno's decision to split **Hazel (engine)** from **Hazelnut (editor)** is one of the most valuable lessons from his series. It demonstrates the importance of treating the editor as a **consumer** of the engine rather than mixing the two.

For our project, we should:
- Keep **zGameLib** as a clean, reusable foundation.
- Make **Nexus-engine** a proper library that can run without an editor.
- Build **Crucible** as a separate application that links against Nexus-engine (using Dear ImGui).

By learning from The Cherno while planning the separation earlier and keeping things more modular and data-oriented, we can build a stronger architecture.

---

*Document created based on public YouTube content and GitHub repository of The Cherno's Hazel project (as of 2026).*
