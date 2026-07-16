const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zgame_dep = b.dependency("zgame", .{
        .target = target,
        .optimize = optimize,
    });

    const nexus_mod = b.addModule("nexus", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    nexus_mod.addImport("zgame", zgame_dep.module("zgame"));

    // ============================================================
    // PRIMARY: Static library (Cherno model — engine as library)
    //   - Consumed by editor, games, and runtimes
    //   - Installed to engine/build/lib/nexus-engine.a/.lib
    // ============================================================
    const nexus_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "nexus-engine",
        .root_module = nexus_mod,
    });
    b.installArtifact(nexus_lib);

    // ============================================================
    // SECONDARY: Runtime executable for standalone testing
    //   - Thin entry point wrapping the same module
    //   - Installed to engine/build/bin/nexus-runtime
    // ============================================================
    const runtime_exe = b.addExecutable(.{
        .name = "nexus-runtime",
        .root_module = nexus_mod,
    });
    b.installArtifact(runtime_exe);

    // ============================================================
    // Named DAG steps for pipeline visibility
    // ============================================================
    const lib_step = b.step("build-lib",
        "Build Nexus static library (primary artifact)");
    lib_step.dependOn(&nexus_lib.step);

    const runtime_step = b.step("build-runtime",
        "Build Nexus runtime executable (standalone testing)");
    runtime_step.dependOn(&runtime_exe.step);

    const engine_step = b.step("build-engine",
        "Build all engine artifacts (static lib + runtime exe)");
    engine_step.dependOn(lib_step);
    engine_step.dependOn(runtime_step);

    const pipeline_step = b.step("pipeline",
        "Full pipeline: zGameLib → Nexus static lib + runtime exe");
    pipeline_step.dependOn(engine_step);
    pipeline_step.dependOn(b.getInstallStep());

    b.default_step = pipeline_step;

    // ============================================================
    // Run (standalone testing)
    // ============================================================
    const run_cmd = b.addRunArtifact(runtime_exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Nexus runtime (standalone testing)");
    run_step.dependOn(&run_cmd.step);
}
