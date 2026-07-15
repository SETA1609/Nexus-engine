# cpp-zig-hybrid-template

A minimal template that compiles and links **Zig**, **C**, and **C++** sources into a single executable using Zig's build system. The Zig program calls into functions defined in C and C++ via `extern` declarations.

There is no separate Make, CMake, or external toolchain — Zig ships its own C/C++ compiler (a frontend over LLVM/Clang), so a single `zig build` step handles every language in this repo.

## Project layout

```
.
├── build.zig               # The entire build system, written in Zig
└── src/
    ├── main.zig            # Entry point; calls into C and C++ functions
    ├── c/
    │   └── greetFromC.c    # Any *.c file here is auto-compiled with -std=c23
    └── cpp/
        └── greetFromCpp.cpp # Any *.cpp file here is auto-compiled with -std=c++23
```

C and C++ live in separate directories so the build script can apply the right compiler flags to each language by walking only the appropriate tree. Subdirectories under `src/c/` and `src/cpp/` are walked recursively.

## How it works

The whole build is driven by `build.zig`. If you've used CMake, think of `build.zig` as the equivalent of `CMakeLists.txt` — except it's written in plain Zig, not a custom DSL.

1. **`build.zig` declares a Module and an executable.** A `Module` is created via `b.createModule(...)` to hold the Zig root file, the target/optimize options, and the libc/libc++ linkage settings. The executable named `demo` is then built from that module via `b.addExecutable(.{ .root_module = exe_mod, ... })`.
2. **C and C++ sources are discovered automatically.** `getFilesFromDir` recursively walks `src/c/` and `src/cpp/`, collects the `.c` and `.cpp` files, and feeds each list to `exe_mod.addCSourceFiles(...)` with the appropriate flags (`-std=c23` for C, `-std=c++23` for C++, plus `-Wall -Wextra -pedantic`). In Zig 0.16 these calls go on the Module, not on the compile step.
3. **libc and libc++ are linked** by setting `link_libc = true` and `link_libcpp = true` on the Module's create options, so the standard libraries are available at runtime.
4. **Cross-language calls** work through the C ABI:
   - In `main.zig`, foreign functions are declared with `extern fn greetFromC() void;` and `extern fn greetFromCpp() void;`.
   - The C function is just a normal C symbol.
   - The C++ function is wrapped in `extern "C"` so its name is not mangled and Zig can resolve it by symbol name at link time.
5. **Linking** is performed by Zig, which produces a single native binary in `zig-out/bin/`.

At runtime, `main.zig` prints a greeting from Zig, calls the C and C++ functions in turn, and prints a success line.

## Requirements

- [Zig](https://ziglang.org/download/) **0.16 or newer**. The build script and `main.zig` use the post-0.16 APIs (the `Io` interface, the `Module`-based `addExecutable`, the unmanaged `ArrayList`, and `pub fn main(init: std.process.Init)`). On older Zig (≤ 0.15) you would need to revert these to their pre-0.16 forms.

No separate C or C++ toolchain is required — Zig provides everything.

## Build & run

Build the binary:

```bash
zig build
```

Build and run in one step:

```bash
zig build run
```

The compiled executable lives at `zig-out/bin/demo` after a successful build.

### Passing arguments

`build.zig` forwards extra arguments to the program:

```bash
zig build run -- arg1 arg2
```

### Release builds

```bash
zig build -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseSafe
zig build -Doptimize=ReleaseSmall
```

### Cross-compiling

Zig can cross-compile for any supported target out of the box, e.g.:

```bash
zig build -Dtarget=x86_64-windows
zig build -Dtarget=aarch64-linux
```

## Adding more sources

Drop the file into the matching directory — that's it.

- A new C file → `src/c/whatever.c` (or any subdirectory below it). It is compiled with the C flags on the next `zig build`.
- A new C++ file → `src/cpp/whatever.cpp`. Same idea, with the C++ flags.

To call a new C/C++ function from Zig, declare it with `extern fn ...` in `main.zig`. For C++, wrap the definition in `extern "C"` so its symbol is not name-mangled.

### A note on stdio buffering across languages

When Zig, C, and C++ share the same `stdin` / `stdout` file descriptors, you can run into ordering and "lost data" problems that have nothing to do with FFI itself — they come from the fact that each language's standard library puts its own buffer on top of the OS file descriptor.

#### Output (stdout)

Zig's `writeStreamingAll` writes directly to the stdout file descriptor, while C's `printf` and C++'s `std::cout` buffer their output and only flush when the program exits (or when a flush is requested). When all three languages share stdout, this means a `printf` line written *before* a Zig line can show up *after* it.

This template solves that by flushing from C and C++ explicitly:

- `greetFromC.c` calls `fflush(stdout);` after each `printf`.
- `greetFromCpp.cpp` writes `std::flush` (or use `std::endl`) at the end of each `<<` chain.

If you add new C/C++ functions that write to stdout, do the same — otherwise their output will land at the end of the program in libc/libc++ teardown order, not at the call site.

`stderr` is unbuffered by default in both C (`fprintf(stderr, ...)`) and C++ (`std::cerr`), so you don't need to flush it. `std::clog` *is* buffered, despite also targeting stderr — easy to forget.

#### Input (stdin)

Reading stdin from more than one language is the symmetric trap. Each runtime keeps its own input buffer, so when C calls `fgets`/`scanf` libc may slurp several kilobytes from the file descriptor and stash the leftover bytes in *its* buffer. A subsequent Zig read of the same fd will not see those bytes — they're invisible to anything outside libc's stdio.

The fix is to **let exactly one language own stdin** for the lifetime of the program. Read everything from there, and pass the data across the FFI boundary as plain function arguments instead of having the other language re-read the descriptor.

#### Why this isn't an FFI bug

Function calls, return values, structs, pointers, memory, threads, and signals are all unaffected — those flow through the C ABI cleanly between Zig, C, and C++. The buffering issue only touches the small set of buffered streams: `stdout`, `std::cout`, `std::clog`, and any `FILE*` you opened with `fopen`. Direct `write(2)` / `read(2)` syscalls bypass libc buffers and don't have this problem either.

If you want to change compiler flags or the language standard, edit the `c_flags` / `cpp_flags` constants near the top of `build.zig`. If you want to add a third language directory or a different extension, the `containsSuffix` and `getFilesFromDir` helpers already accept arbitrary extension lists; you just need another `addCSourceFiles` call in `build()`.

## Why Zig instead of CMake / Make?

This project uses Zig's build system in place of the usual C/C++ toolchain. The trade-offs are honest, not absolute — here's the short version.

### Pros

- **Single-tool install.** Zig ships the build system, a Clang-based C/C++ frontend, libc/libc++ headers, and an LLVM backend in one ~150 MB tarball. No `apt install build-essential cmake ninja-build`, no Visual Studio, no Xcode command-line tools.
- **Cross-compilation is built in.** `zig build -Dtarget=aarch64-linux` just works — Zig bundles libc for every supported target. With CMake this typically means a sysroot, a toolchain file, and a working cross-compiler installation.
- **Reproducible across machines.** A given Zig version produces the same binary regardless of which gcc/clang the host has installed. No "works on my machine because I'm on gcc 13" surprises.
- **The build script is a real programming language.** You write loops, conditionals, and helper functions in Zig itself — see how `getFilesFromDir` recursively scans a directory in this repo. CMake's `function()` / `if(...)` syntax is its own DSL with its own quirks.
- **One phase, not two.** Zig builds directly. No "configure, then generate, then build" dance like `cmake -B build && cmake --build build`.
- **Fast, content-addressed cache.** Incremental builds are quick and stable.

### Cons

- **Tiny ecosystem.** Almost no upstream C/C++ library ships a `build.zig`. Most assume CMake, autotools, or Make. Pulling in a non-trivial dependency often means writing a `build.zig` shim for it yourself.
- **Pre-1.0.** Zig's build API still changes between releases — the 0.15 → 0.16 jump alone moved C/C++ sources and libc linkage onto Modules, threaded an explicit `Io` interface through every filesystem call, switched `ArrayList` to unmanaged-by-default, and changed the signature of `pub fn main`. Code that compiles today may need a small migration after a Zig upgrade. CMake, by contrast, has decades of stability.
- **Less community knowledge.** Stack Overflow, vendor docs, and AI training data lean *heavily* CMake/Make. When something breaks, error messages are harder to search for.
- **Tooling integration is thinner.** CMake produces a `compile_commands.json` (used by clangd, IDEs, static analyzers) as a first-class output. Zig can produce one via `zig build --verbose` post-processing, but it's not as smooth. CTest, CPack, and CDash have no direct Zig analogs.
- **You're tied to Zig's bundled LLVM/Clang.** If you specifically need MSVC, GCC, or a vendor-specific compiler, Zig's toolchain doesn't help.
- **Large or dependency-heavy C++ projects suffer most.** `find_package(Boost)`, `FetchContent`, and the Conan/vcpkg ecosystem are battle-tested in CMake. The Zig equivalent is bring-your-own.

### Rule of thumb

- **Greenfield, small-to-mid project, want cross-compile and one tool?** Zig build is excellent.
- **Tiny C/C++ shim called from Zig?** Zig build is the obvious choice (this repo).
- **Existing C++ codebase with heavy deps, or a team that already knows CMake?** Stay on CMake. The migration cost rarely pays off.

## Documentation note

The prose in this README and the explanatory comments inside `build.zig` were written with the help of an AI assistant (Claude). The code itself was authored interactively — the AI suggested fixes, flagged bugs, and explained Zig 0.16 API changes, but the design decisions (per-language directories, auto-discovery, the build-system choice) are the project author's. Treat the docs as a starting point: if you spot something that doesn't match the code, the code is the source of truth.
