// This script is the entire build system for the project. Running `zig build`
// invokes the `build` function at the bottom; everything above it is
// configuration and helpers. If you only know CMake/Make: `build.zig` is
// played as the role of `CMakeLists.txt`, but written in plain Zig instead
// of a custom DSL.
//
// To customize the build, you usually only need to touch the constants
// directly below: where the C/C++ sources live and which compiler flags
// to use.

const std = @import("std");

// --- Configuration --------------------------------------------------------
// File extensions used to identify compilation units. Headers (.h, .hpp)
// are intentionally not listed: they are #included by .c/.cpp files and
// must NOT be passed to the compiler as standalone inputs.
const c_suffix = ".c";
const cpp_suffix = ".cpp";

// Where the script looks for sources. Anything ending in `c_suffix` under
// `path_to_c` is compiled as C; anything ending in `cpp_suffix` under
// `path_to_cpp` is compiled as C++. Subdirectories are walked recursively,
// so e.g. `src/c/util/foo.c` is picked up automatically.
const path_to_c = "src/c";
const path_to_cpp = "src/cpp";

// Compiler flags forwarded to Zig's bundled Clang frontend. `++` is Zig's
// compile-time array-concatenation operator, so `c_flags` ends up as
// {"-std=c23", "-Wall", "-Wextra", "-pedantic"}.
const base_flags = [_][]const u8{ "-Wall", "-Wextra", "-pedantic" };
const c_flags = [_][]const u8{"-std=c23"} ++ base_flags;
// Bump this when Zig's bundled Clang gains better C++26 support.
const cpp_flags = [_][]const u8{"-std=c++23"} ++ base_flags;

// --- Source discovery -----------------------------------------------------

/// Returns true if `file` ends with any of the given `extensions`.
/// Used by `getFilesFromDir` to keep only translation units (.c/.cpp).
fn containsSuffix(
    file: []const u8,
    extensions: []const []const u8,
) bool {
    for (extensions) |extension| if (std.mem.endsWith(u8, file, extension)) return true;
    return false;
}

/// Recursively walks `dir_path` and returns the relative paths of every
/// regular file whose name ends in one of the given `extensions`.
///
/// `io` is Zig's I/O interface (introduced in 0.16's "color-blind async"
/// refactor). Every filesystem call now takes it explicitly. In a build
/// script the value comes from `b.graph.io`.
///
/// The returned slice and its strings are owned by `allocator`. In the
/// build script we use `b.allocator`, which lives for the duration of the
/// build, so we never explicitly free them.
fn getFilesFromDir(
    io: std.Io,
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    extensions: []const []const u8,
) ![]const []const u8 {
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close(io);
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    // 0.16 unified ArrayList around the unmanaged form: initialize with
    // `.empty` and pass the allocator to each mutating call.
    var list: std.ArrayList([]const u8) = .empty;
    errdefer list.deinit(allocator);

    while (try walker.next(io)) |entry| {
        if (entry.kind == .file and containsSuffix(entry.path, extensions)) {
            // `entry.path` is relative to the walked dir, so prepend
            // `dir_path` to get a path the compiler can resolve from cwd.
            const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
            try list.append(allocator, full_path);
        }
    }
    return list.toOwnedSlice(allocator);
}

// --- Build entry point ----------------------------------------------------
// `zig build` calls this function once. It does not compile anything
// directly — instead it describes a graph of build steps (compile, link,
// install, run) that Zig then executes in dependency order.
pub fn build(b: *std.Build) void {
    // Target triple (CPU/OS/ABI). Defaults to the host. Override on the
    // command line, e.g. `zig build -Dtarget=x86_64-windows`.
    const target = b.standardTargetOptions(.{});

    // Optimization mode. Defaults to Debug. Override with
    // `-Doptimize=ReleaseFast | ReleaseSafe | ReleaseSmall`.
    const optimize = b.standardOptimizeOption(.{});

    // Discover C and C++ sources at build-script run time instead of
    // listing them by hand. Drop a new file into `src/c/` or `src/cpp/`
    // (or any subdirectory of those) and it gets picked up automatically
    // on the next `zig build`. Failure to read the directory is fatal —
    // there is no useful recovery in a build script, so we panic.
    const c_sources = getFilesFromDir(b.graph.io, b.allocator, path_to_c, &.{c_suffix}) catch |err|
        std.debug.panic("Failed to scan {s}: {s}", .{ path_to_c, @errorName(err) });
    const cpp_sources = getFilesFromDir(b.graph.io, b.allocator, path_to_cpp, &.{cpp_suffix}) catch |err|
        std.debug.panic("Failed to scan {s}: {s}", .{ path_to_cpp, @errorName(err) });

    // Build a Module that owns the root Zig file plus all C/C++ sources.
    // In modern Zig (0.14+) C/C++ files and libc/libc++ linkage are
    // attached to a Module, not directly to the executable.
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        // Link libc for things like `printf`, and libc++ for `std::cout`
        // and the rest of the C++ runtime.
        .link_libc = true,
        .link_libcpp = true,
    });

    // Hand the C sources to Zig's bundled Clang-based C frontend. No
    // external C compiler is required.
    exe_mod.addCSourceFiles(.{
        .files = c_sources,
        .flags = &c_flags,
    });

    // Same for C++. Each C++ function called from Zig must be declared
    // `extern "C"` in its .cpp file, otherwise its symbol gets C++
    // name-mangled and Zig's `extern fn` won't find it at link time.
    exe_mod.addCSourceFiles(.{
        .files = cpp_sources,
        .flags = &cpp_flags,
    });

    // The artifact this build produces: a binary called `demo`, built
    // from the module above.
    const exe = b.addExecutable(.{
        .name = "demo",
        .root_module = exe_mod,
    });

    // Place the final binary under `zig-out/bin/` when the user runs
    // `zig build` (the default install step).
    b.installArtifact(exe);

    // Wire up `zig build run`: a step that depends on the install step
    // (so the binary exists on disk first) and then executes it.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Forward CLI args after `--` straight to the program, so
    // `zig build run -- foo bar` passes ["foo", "bar"] to main().
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Expose the run command as a named top-level step. Shows up in
    // `zig build --help` and is invoked with `zig build run`.
    const run_step = b.step("run", "Run the demo application");
    run_step.dependOn(&run_cmd.step);
}
