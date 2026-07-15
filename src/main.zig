const std = @import("std");

extern fn greetFromC() void;
extern fn greetFromCpp() void;

// Zig 0.16 changed `main`: instead of grabbing globals like `std.io.getStdOut()`,
// the runtime hands you an `Init` struct that carries the I/O interface.
// `init.io` is what filesystem and stdio calls thread through.
pub fn main(init: std.process.Init) !void {
    const stdout = std.Io.File.stdout();
    try stdout.writeStreamingAll(init.io, "🚀 Hello from Zig! \n");
    greetFromC();
    greetFromCpp();
    try stdout.writeStreamingAll(init.io, "\n ✅ Success!\n");
}
