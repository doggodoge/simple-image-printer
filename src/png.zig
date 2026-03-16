const std = @import("std");

const CHUNK_SIZE = 4096; // kitty requires base64 chunks to be max this.
const BUFFER_SIZE = 128 * 1024;

pub fn handOverSharedMemory(allocator: std.mem.Allocator, file_name: []const u8) !void {
    var arena_instance = std.heap.ArenaAllocator.init(allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const file_handle = try std.fs.cwd().openFile(file_name, .{});
    defer file_handle.close();
    const file_stat = try file_handle.stat();

    const pid = std.posix.system.getpid();
    const hash = try getRandomHash(arena);
    const shm_name_long = try std.fmt.allocPrint(arena, "/{d}-{s}", .{ pid, hash });

    const shm_name = shm_name_long[0..@min(30, shm_name_long.len)];
    const c_shm_name = try arena.dupeZ(u8, shm_name); // should be fine.

    // note: the terminal emulator is responsible for freeing the shared memory
    // object, not us. We should NOT call shm_unlink.
    const shm_open_flags: std.posix.O = .{
        .ACCMODE = .RDWR,
        .CREAT = true,
        .EXCL = true,
    };
    const shm_fd = std.c.shm_open(c_shm_name.ptr, @bitCast(shm_open_flags), 0o600);
    if (shm_fd == -1) {
        return error.ShmOpenFailed;
    }
    defer _ = std.c.close(shm_fd);

    try std.posix.ftruncate(shm_fd, file_stat.size);

    const mapped_bytes = try std.posix.mmap(
        null,
        file_stat.size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .SHARED },
        shm_fd,
        0,
    );
    defer std.posix.munmap(mapped_bytes);

    _ = try file_handle.readAll(mapped_bytes);
    try std.posix.msync(mapped_bytes, std.posix.MSF.SYNC);

    const base64_len = std.base64.standard.Encoder.calcSize(shm_name.len);
    const base64_buf = try arena.alloc(u8, base64_len);
    _ = std.base64.standard.Encoder.encode(base64_buf, shm_name);

    const stdout_buffer = try arena.alloc(u8, 16 * 1024);
    var stdout_writer = std.fs.File.stdout().writer(stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print(
        "\x1b_Gf=100,a=T,t=s,S={d},O=0;{s}\x1b\\\n",
        .{ file_stat.size, base64_buf },
    );
    try stdout.flush();
}

pub fn streamBase64ToStdout(allocator: std.mem.Allocator, file_name: []const u8) !void {
    var arena_instance = std.heap.ArenaAllocator.init(allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var stdout_buffer: [BUFFER_SIZE]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const file_handle = try std.fs.cwd().openFile(file_name, .{});
    defer file_handle.close();
    const file_data = try file_handle.readToEndAlloc(arena, std.math.maxInt(usize));

    const out_len = std.base64.standard.Encoder.calcSize(file_data.len);
    const base64_buffer = try arena.alloc(u8, out_len);
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

/// Creates Random every call, rewrite to pass in Random if need to call
/// frequently.
fn getRandomHash(allocator: std.mem.Allocator) ![]u8 {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();
    const random_val = random.int(u64);
    const hash_val = std.hash.Wyhash.hash(0, std.mem.asBytes(&random_val));

    return std.fmt.allocPrint(allocator, "{x}", .{hash_val});
}
