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

    const exe = b.addExecutable(.{
        .name = "nexus-engine",
        .root_module = nexus_mod,
    });

    b.installArtifact(exe);

    // ============================================================
    // Named DAG steps for pipeline visibility.
    // The module → dependency edges already form the internal DAG;
    // these steps make it visible in `--summary all`.
    // ============================================================
    const engine_step = b.step("build-engine",
        "Build Nexus-engine binary");
    engine_step.dependOn(&exe.step);

    const pipeline_step = b.step("pipeline",
        "Full pipeline: zGameLib → Nexus-engine");
    pipeline_step.dependOn(engine_step);

    b.default_step = pipeline_step;

    // ============================================================
    // Run
    // ============================================================
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Nexus engine");
    run_step.dependOn(&run_cmd.step);
}
