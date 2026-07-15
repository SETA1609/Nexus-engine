const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;

pub fn main() !void {
    try platform.init(.{});
    defer platform.deinit();

    const win = try platform.Window.create(.{
        .title = "Nexus Engine",
        .size = .{ .w = 1280, .h = 720 },
        .renderer = .vulkan,
    });
    defer win.destroy();

    std.debug.print("Nexus Engine — Tier 2 on zGameLib (Tier 1)\n", .{});

    while (!win.shouldClose()) {
        platform.pollAllEvents();
    }
}
