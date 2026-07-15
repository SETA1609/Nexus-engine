//! Build for Nexus-engine — a Tier 2 engine consuming zGameLib (Tier 1).
//!
//! The engine module imports `zgame` from the framework dependency; the
//! executable links the platform + vulkan_stack + zclip artifacts that
//! `zgame` pulls in. Add engine-native C/C++ sources as needed below.

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zgame_dep = b.dependency("zgame", .{
        .target = target,
        .optimize = optimize,
    });

    const nexus_mod = b.createModule(.{
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

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the Nexus engine");
    run_step.dependOn(&run_cmd.step);
}
