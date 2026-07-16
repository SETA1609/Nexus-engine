//! Public Nexus Engine API — consumed via `nexus` module import + static lib linkage.

const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;

pub const NexusApp = struct {
    window: *platform.Window,

    pub const Options = struct {
        title: [:0]const u8 = "Nexus Engine",
        width: u32 = 1280,
        height: u32 = 720,
    };

    pub fn init(options: Options) !NexusApp {
        try platform.init(.{});
        const window = try platform.Window.create(.{
            .title = options.title,
            .size = .{ .w = @intCast(options.width), .h = @intCast(options.height) },
            .renderer = .vulkan,
        });
        return .{ .window = window };
    }

    pub fn deinit(self: *NexusApp) void {
        self.window.destroy();
        self.window = undefined;
        platform.deinit();
    }

    pub fn shouldClose(self: *const NexusApp) bool {
        return self.window.shouldClose();
    }

    pub fn tick(self: *NexusApp) !void {
        _ = self;
        platform.pollAllEvents();
    }
};