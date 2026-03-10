const std = @import("std");
const icat = @import("icat");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var arena_instance = std.heap.ArenaAllocator.init(allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    defer std.process.argsFree(arena, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file_name>\n", .{args[0]});
        std.process.exit(1);
    }
    const file_name = args[1];

    try icat.png.streamBase64ToStdout(arena, file_name);
}
