const std = @import("std");
const icat = @import("icat");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file_name>\n", .{args[0]});
        std.process.exit(1);
    }
    const file_name = args[1];

    if (try icat.features.canUseSharedMemory(allocator)) {
        try icat.png.handOverSharedMemory(allocator, file_name);
    } else {
        try icat.png.streamBase64ToStdout(allocator, file_name);
    }
}
