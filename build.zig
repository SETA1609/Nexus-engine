const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zgame_dep = b.dependency("zgame", .{
        .target = target,
        .optimize = optimize,
    });

    const nexus_mod = b.addModule("nexus", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    nexus_mod.addImport("zgame", zgame_dep.module("zgame"));
    nexus_mod.addImport("engine_interface", b.createModule(.{
        .root_source_file = b.path("../contract/engine_interface.zig"),
        .target = target,
        .optimize = optimize,
    }));

    // ============================================================
    // PATH 1 — Static library (Cherno: Hazel core engine)
    //   Primary artifact: engine/build/lib/libnexus-engine.a
    //   No editor code. Consumed by runtime, editor, and games.
    // ============================================================
    const nexus_lib = b.addLibrary(.{
        .linkage = .static,
        .name = "nexus-engine",
        .root_module = nexus_mod,
    });

    const install_lib = b.addInstallArtifact(nexus_lib, .{});

    const lib_step = b.step("build-lib",
        "Build libnexus-engine.a (Cherno engine core — no editor)");
    lib_step.dependOn(&nexus_lib.step);
    lib_step.dependOn(&install_lib.step);

    // ============================================================
    // PATH 2 — Runtime executable (Cherno: game without editor)
    //   Thin entry point linking the static lib — no ImGui, no tools.
    //   Installed to engine/build/bin/nexus-runtime
    // ============================================================
    const runtime_mod = b.createModule(.{
        .root_source_file = b.path("src/runtime/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    runtime_mod.addImport("nexus", nexus_mod);
    runtime_mod.linkLibrary(nexus_lib);

    const runtime_exe = b.addExecutable(.{
        .name = "nexus-runtime",
        .root_module = runtime_mod,
    });

    const install_runtime = b.addInstallArtifact(runtime_exe, .{});

    const runtime_step = b.step("build-runtime",
        "Build nexus-runtime (no-editor consumer of libnexus-engine.a)");
    runtime_step.dependOn(lib_step);
    runtime_step.dependOn(&runtime_exe.step);
    runtime_step.dependOn(&install_runtime.step);

    // ============================================================
    // Aggregated engine step — both Cherno paths
    // ============================================================
    const engine_step = b.step("build-engine",
        "Build engine: static lib + no-editor runtime");
    engine_step.dependOn(lib_step);
    engine_step.dependOn(runtime_step);

    const pipeline_step = b.step("pipeline",
        \\Full engine pipeline: zGameLib → libnexus-engine.a → nexus-runtime
        \\
        \\  zig build build-lib       # static lib only
        \\  zig build build-runtime   # no-editor runtime (requires lib)
        \\  zig build build-engine    # both paths
        \\  zig build run             # run nexus-runtime
    );
    pipeline_step.dependOn(engine_step);

    b.default_step = pipeline_step;

    // ============================================================
    // Run — no-editor runtime only (not the editor)
    // ============================================================
    const run_cmd = b.addRunArtifact(runtime_exe);
    run_cmd.step.dependOn(&install_runtime.step);

    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run nexus-runtime (engine without editor)");
    run_step.dependOn(&run_cmd.step);
}