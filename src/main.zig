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

test "decode data instrs" {
    var buf: [1024]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    const test_data = [_]u32{ 0xE0810002, 0xE24430FF, 0xE1550006, 0xE1A07008, 0x120A9005, 0xE19CB00D, 0xE3E0E00A, 0x00610002, 0xE3330055, 0x21D54006 };
    const expected =
        \\ADD R0, R1, R2
        \\SUB R3, R4, #0xff
        \\CMP R5, R6
        \\MOV R7, R8
        \\ANDNE R9, R10, #0x5
        \\ORRS R11, R12, R13
        \\MVN R14, #0xa
        \\RSBEQ R0, R1, R2
        \\TEQ R3, #0x55
        \\BICCSS R4, R5, R6
    ;

    try decoder.decode(&w, &test_data);

    try std.testing.expectEqualStrings(expected, buf[0..expected.len]);
}

test "decode sdt instrs" {
    var buf: [1024]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    const test_data = [_]u32{ 0xE5910008, 0xE5232004, 0xE4D54001, 0xE7C76008, 0xE73A910B, 0x158DC020, 0x041E0008, 0xE7C21243, 0xE4B54010, 0xE7676468 };
    const expected =
        \\LDR R0, [R1, #0x8]
        \\STR R2, [R3, #-0x4]!
        \\LDRB R4, [R5], #0x1
        \\STRB R6, [R7, R8]
        \\LDR R9, [R10, -R11, LSL #2]!
        \\STRNE R12, [R13, #0x20]
        \\LDREQ R0, [R14], #-0x8
        \\STRB R1, [R2, R3, ASR #4]
        \\LDRT R4, [R5], #0x10
        \\STRB R6, [R7, -R8, ROR #8]!
    ;

    try decoder.decode(&w, &test_data);

    try std.testing.expectEqualStrings(expected, buf[0..expected.len]);
}

test "decode branch instrs" {
    var buf: [1024]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    const test_data = [_]u32{
        0xEA000001,
        0xEB000010,
        0x0AFFFFFC,
        0x1BFFFFF6,
        0x3A000100,
        0x4B000000,
        0xCAFFFFFE,
        0xDAFFFF00,
        0x6B00002A,
        0xEAFFFFFD,
    };

    const expected =
        \\B .+0xc
        \\BL .+0x48
        \\BEQ .-0x8
        \\BLNE .-0x20
        \\BCC .+0x408
        \\BLMI .+0x8
        \\BGT .+0x0
        \\BLE .-0x3f8
        \\BLVS .+0xb0
        \\B .-0x4
    ;

    try decoder.decode(&w, &test_data);

    try std.testing.expectEqualStrings(expected, buf[0..expected.len]);
}
