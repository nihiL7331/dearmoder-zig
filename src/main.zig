const std = @import("std");
const Io = std.Io;

const decoder = @import("decoder.zig");

fn tokenize_instrs(allocator: std.mem.Allocator, file_data: []u8) ![]u32 {
    var instrs: std.ArrayList(u32) = .empty;

    var it = std.mem.tokenizeAny(u8, file_data, "\r\n ");

    while (it.next()) |hex_str| {
        const instr = try std.fmt.parseInt(u32, hex_str, 16);
        try instrs.append(allocator, instr);
    }

    return instrs.items;
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    if (args.len < 2) {
        std.debug.print("Usage: {s} <path>\n", .{args[0]});
        return;
    }

    const file_path = args[1];

    const file_data = try Io.Dir.readFileAlloc(
        Io.Dir.cwd(),
        init.io,
        file_path,
        arena,
        Io.Limit.unlimited,
    );

    const data: []u32 = try tokenize_instrs(arena, file_data);

    const stdout_file = std.Io.File.stdout();
    var buf: [4096]u8 = undefined;
    const w = stdout_file.writer(init.io, &buf);
    var stdout = w.interface;

    try decoder.decode(&stdout, data);

    try stdout.flush();
}

test "decode sdt instrs" {
    const test_data = [_]u32{ 0xE5910008, 0xE5232004, 0xE4D54001, 0xE7C76008, 0xE73A910B, 0x158DC020, 0x041E0008, 0xE7C21243, 0xE4B54010, 0xE7676468 };
    try decoder.decode(&test_data);
}
