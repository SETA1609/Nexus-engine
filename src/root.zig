//! Public Nexus Engine API — consumed via `nexus` module import + static lib linkage.
//!
//! For Link-editor integration, use `createEngineInterface()` which wraps
//! NexusApp behind the engine-agnostic `EngineInterface` vtable.

const std = @import("std");
const zgame = @import("zgame");
const platform = zgame.platform;
const engine_iface = @import("engine_interface");

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

/// Export the engine factory as a C-ABI symbol so the editor can discover it
/// via @extern through the linked static library — no direct module import needed.
export fn createEngineInterface() engine_iface.EngineInterface {
    const allocator = std.heap.page_allocator;
    const app = allocator.create(NexusApp) catch @panic("OOM");
    app.* = undefined;
    return engine_iface.EngineInterface.wrap(
        @ptrCast(app),
        &.{
            .init = nexusInit,
            .deinit = nexusDeinit,
            .tick = nexusTick,
            .shouldClose = nexusShouldClose,
            .getEngineName = nexusGetName,
            .getEngineVersion = nexusGetVersion,
        },
    );
}

fn nexusInit(ctx: *anyopaque, opts: engine_iface.EngineOptions) !void {
    const app = @as(*NexusApp, @ptrCast(@alignCast(ctx)));
    app.* = try NexusApp.init(.{
        .title = opts.title,
        .width = opts.width,
        .height = opts.height,
    });
}

fn nexusDeinit(ctx: *anyopaque) void {
    const app = @as(*NexusApp, @ptrCast(@alignCast(ctx)));
    app.deinit();
    const allocator = std.heap.page_allocator;
    allocator.destroy(app);
}

fn nexusTick(ctx: *anyopaque) !void {
    const app = @as(*NexusApp, @ptrCast(@alignCast(ctx)));
    try app.tick();
}

fn nexusShouldClose(ctx: *anyopaque) bool {
    const app = @as(*const NexusApp, @ptrCast(@alignCast(ctx)));
    return app.shouldClose();
}

fn nexusGetName(ctx: *anyopaque) []const u8 {
    _ = ctx;
    return "Nexus Engine";
}

fn nexusGetVersion(_: *anyopaque) u32 {
    return 1;
}