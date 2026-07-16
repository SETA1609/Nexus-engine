//! No-editor runtime entry point (Cherno: game ships without Hazelnut).
//! Thin consumer of libnexus-engine.a — no ImGui, no editor panels.

const std = @import("std");
const nexus = @import("nexus");

pub fn main() !void {
    var app = try nexus.NexusApp.init(.{
        .title = "Nexus Runtime",
        .width = 1280,
        .height = 720,
    });
    defer app.deinit();

    std.debug.print("Nexus Runtime — engine without editor (Tier 2 on zGameLib)\n", .{});

    while (!app.shouldClose()) {
        try app.tick();
    }
}