const std = @import("std");
const Io = std.Io;

const decoder = @import("decoder.zig");

fn tokenizeInstrs(allocator: std.mem.Allocator, file_data: []u8) ![]u32 {
    var instrs: std.ArrayList(u32) = .empty;

    var it = std.mem.tokenizeAny(u8, file_data, "\r\n ");

    while (it.next()) |hex_str| {
        const instr = try std.fmt.parseInt(u32, hex_str, 16);
        try instrs.append(allocator, instr);
    }

    return instrs.toOwnedSlice(allocator);
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

    const data: []u32 = try tokenizeInstrs(arena, file_data);
    const byte_data = std.mem.sliceAsBytes(&data);

    const stdout_file = std.Io.File.stdout();
    var buf: [4096]u8 = undefined;
    const w = stdout_file.writer(init.io, &buf);
    var stdout = w.interface;

    var dec = decoder.Decoder.init(0, .Arm);
    try dec.decodeBlock(&w, byte_data);

    try stdout.flush();
}

test "run all module tests" {
    _ = @import("arm.zig");
}
