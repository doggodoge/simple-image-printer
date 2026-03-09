const std = @import("std");

const CHUNK_SIZE = 4096; // kitty requires base64 chunks to be max this.
const BUFFER_SIZE = 128 * 1024;

pub fn streamBase64ToStdout(allocator: std.mem.Allocator, file_name: []const u8) !void {
    var stdout_buffer: [BUFFER_SIZE]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const file_handle = try std.fs.cwd().openFile(file_name, .{});
    defer file_handle.close();
    const file_data = try file_handle.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(file_data);

    const out_len = std.base64.standard.Encoder.calcSize(file_data.len);
    const base64_buffer = try allocator.alloc(u8, out_len);
    defer allocator.free(base64_buffer);
    _ = std.base64.standard.Encoder.encode(base64_buffer, file_data);

    var i: usize = 0;
    var first: bool = true;
    while (i < base64_buffer.len) : (i += CHUNK_SIZE) {
        const end = @min(i + CHUNK_SIZE, base64_buffer.len);
        const chunk = base64_buffer[i..end];
        const is_last = end == base64_buffer.len;

        try stdout.writeAll("\x1b_G");

        if (first) {
            try stdout.writeAll("f=100,a=T,");
            first = false;
        }

        if (!is_last) {
            try stdout.writeAll("m=1;");
        } else {
            try stdout.writeAll("m=0;");
        }

        try stdout.writeAll(chunk);
        try stdout.writeAll("\x1b\\");
    }

    try stdout.writeAll("\n");
    try stdout.flush();
}
