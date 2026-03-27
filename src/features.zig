const std = @import("std");
const hasEnvVar = std.process.hasEnvVar;

pub fn canUseSharedMemory(allocator: std.mem.Allocator) !bool {
    var arena_instance = std.heap.ArenaAllocator.init(allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const has_ssh_client = try hasEnvVar(arena, "SSH_CLIENT");
    const has_ssh_connection = try hasEnvVar(arena, "SSH_CONNECTION");
    const has_ssh_tty = try hasEnvVar(arena, "SSH_TTY");

    return !(has_ssh_client or has_ssh_connection or has_ssh_tty);
}
