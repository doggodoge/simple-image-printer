const std = @import("std");
const icat = @import("icat");

const CHUNK_SIZE = 4096;

pub fn main() !void {
    const gpa = std.heap.raw_c_allocator;
    var arena_instance = std.heap.ArenaAllocator.init(gpa);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    defer std.process.argsFree(arena, args);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <file_name>\n", .{args[0]});
        std.process.exit(1);
    }

    const file_name = args[1];

    const page_size = std.heap.pageSize();
    const buffer = try arena.alloc(u8, page_size);
    defer arena.free(buffer);

    var stdout_writer = std.fs.File.stdout().writer(buffer);
    const stdout = &stdout_writer.interface;

    const file_handle = try std.fs.cwd().openFile(file_name, .{});
    const file_data = try file_handle.readToEndAlloc(arena, std.math.maxInt(usize));
    defer arena.free(file_data);

    const out_len = std.base64.standard.Encoder.calcSize(file_data.len);
    const buf = try arena.alloc(u8, out_len);
    defer arena.free(buf);
    const base64_encoded_data = buf[0..out_len];
    _ = std.base64.standard.Encoder.encode(buf, file_data);

    var i: usize = 0;
    var first: bool = true;
    while (i < base64_encoded_data.len) : (i += CHUNK_SIZE) {
        const end = @min(i + CHUNK_SIZE, base64_encoded_data.len);
        const chunk = base64_encoded_data[i..end];
        const is_last = end == base64_encoded_data.len;

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
