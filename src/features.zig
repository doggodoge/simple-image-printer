const std = @import("std");

pub fn canUseSharedMemory(allocator: std.mem.Allocator) !bool {
    var arena_instance = std.heap.ArenaAllocator.init(allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var env_map = try std.process.getEnvMap(arena);

    const has_ssh_client = env_map.hash_map.contains("SSH_CLIENT");
    const has_ssh_connection = env_map.hash_map.contains("SSH_CONNECTION");
    const has_ssh_tty = env_map.hash_map.contains("SSH_TTY");

    return !(has_ssh_client or has_ssh_connection or has_ssh_tty);
}
