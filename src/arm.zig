const std = @import("std");

const DataInstr = packed struct(u32) {
    rm: u12, // operand 2: the second value, reg/num
    rd: u4, // dest reg
    rn: u4, // first src reg
    s: u1, // set cond flags
    opcode: u4,
    i: u1, // immediate flag
    id: u2,
    cond: u4,
};

const BranchInstr = packed struct(u32) {
    offset: u24, // how far fw/bw to jump
    l: u1, // link bit
    id: u3,
    cond: u4,
};

const SingleInstr = packed struct(u32) {
    offset: u12, // offset to apply to the ptr
    rd: u4, // src/dest reg for the ptr
    rn: u4, // base register
    l: u1, // load/store
    w: u1, // write-back
    b: u1, // byte/word
    u: u1, // up/down
    p: u1, // pre/post indexing
    i: u1, // immediate offset flag
    id: u2,
    cond: u4,
};

const SingleOffset = packed struct(u12) {
    rm: u4,
    _: u1,
    s_type: u2,
    s_size: u5,
};

const data_opcodes = [_][]const u8{
    "AND", "EOR", "SUB", "RSB", "ADD", "ADC", "SBC", "RSC",
    "TST", "TEQ", "CMP", "CMN", "ORR", "MOV", "BIC", "MVN",
};

const branch_opcodes = [_][]const u8{ "B", "BL" };

const sdt_opcodes = [_][]const u8{ "STR", "LDR" };

const conds = [_][]const u8{
    "EQ", "NE", "CS", "CC", "MI", "PL", "VS", "VC",
    "HI", "LS", "GE", "LT", "GT", "LE", "", "", // 14 (AL) prints nothing
};

const s_types = [_][]const u8{
    "LSL", "LSR", "ASR", "ROR",
};

const s_suffix = [_][]const u8{ "", "S" };

const u_prefix = [_][]const u8{ "-", "" };

const b_suffix = [_][]const u8{ "", "B" };

fn printDataInstr(writer: anytype, instr: DataInstr) !void {
    switch (instr.opcode) {
        0b1000...0b1011 => {
            try writer.print("{s}{s} R{d}, ", .{ data_opcodes[instr.opcode], conds[instr.cond], instr.rn });
        },
        0b1101, 0b1111 => {
            try writer.print("{s}{s}{s} R{d}, ", .{ data_opcodes[instr.opcode], conds[instr.cond], s_suffix[instr.s], instr.rd });
        },
        else => {
            try writer.print("{s}{s}{s} R{d}, R{d}, ", .{ data_opcodes[instr.opcode], conds[instr.cond], s_suffix[instr.s], instr.rd, instr.rn });
        },
    }

    if (instr.i == 1) {
        const imm8: u32 = instr.rm & 0xFF;
        const rot: u5 = @as(u5, @truncate(instr.rm >> 8)) * 2;

        const actual_val = std.math.rotr(u32, imm8, rot);
        try writer.print("#0x{x}\n", .{actual_val});
    } else {
        try writer.print("R{d}\n", .{instr.rm});
    }
}

fn printBranchInstr(writer: anytype, instr: BranchInstr) !i32 {
    const opcode = branch_opcodes[instr.l];

    const sgn_off: i32 = @as(i24, @bitCast(instr.offset));
    const byte_off = sgn_off * 4 + 8;

    if (byte_off >= 0) {
        try writer.print("{s}{s} .+0x{x}\n", .{ opcode, conds[instr.cond], byte_off });
    } else {
        try writer.print("{s}{s} .-0x{x}\n", .{ opcode, conds[instr.cond], -byte_off });
    }

    return byte_off;
}

fn printSdtInstr(writer: anytype, instr: SingleInstr) !void {
    const opcode = sdt_opcodes[instr.l];

    try writer.print("{s}{s}{s}{s} R{d}, ", .{ opcode, conds[instr.cond], b_suffix[instr.b], if (instr.p == 0 and instr.w == 1) "T" else "", instr.rd });

    try writer.print("[R{d}", .{instr.rn});

    if (instr.p == 0) {
        try writer.print("]", .{});
    }

    if (instr.i == 1) {
        const offset: SingleOffset = @bitCast(instr.offset);

        try writer.print(", {s}R{d}", .{ u_prefix[instr.u], offset.rm });
        if (offset.s_size == 0) {
            if (offset.s_type == 0b11) { // shift_type == "ROR"
                try writer.print(", RRX", .{});
            } else if (offset.s_type != 0b00) { // shift_type != "LSL"
                try writer.print(", {s} #32", .{s_types[offset.s_type]});
            }
        } else {
            try writer.print(", {s} #{d}", .{ s_types[offset.s_type], offset.s_size });
        }
    } else {
        try writer.print(", #{s}0x{x}", .{ u_prefix[instr.u], instr.offset });
    }

    if (instr.p == 1) {
        try writer.print("]", .{});

        if (instr.w == 1) {
            try writer.print("!", .{});
        }
    }

    try writer.print("\n", .{});
}

pub fn decodeInstr(writer: anytype, instr: u32) !?i32 {
    const id: u3 = @truncate((instr >> 25) & 0b111);

    switch (id) {
        0b000, 0b001 => {
            const data_instr: DataInstr = @bitCast(instr);
            try printDataInstr(writer, data_instr);
            return null;
        },
        0b101 => {
            const branch_instr: BranchInstr = @bitCast(instr);
            return try printBranchInstr(writer, branch_instr);
        },
        0b010, 0b011 => {
            const sdt_instr: SingleInstr = @bitCast(instr);
            try printSdtInstr(writer, sdt_instr);
            return null;
        },
        else => {
            try writer.print("Unimplemented block\n", .{});
            return null;
        },
    }
}

test "decode data instrs" {
    var buf: [1024]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    const test_data = [_]u32{
        0xE0810002,
        0xE24430FF,
        0xE1550006,
        0xE1A07008,
        0x120A9005,
        0xE19CB00D,
        0xE3E0E00A,
        0x00610002,
        0xE3330055,
        0x21D54006,
    };
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

    var pc: u32 = 0;
    while (pc < test_data.len) : (pc += 1) {
        _ = try decodeInstr(&w, test_data[pc]);
    }

    try std.testing.expectEqualStrings(expected, buf[0..expected.len]);
}

test "decode sdt instrs" {
    var buf: [1024]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);

    const test_data = [_]u32{
        0xE5910008,
        0xE5232004,
        0xE4D54001,
        0xE7C76008,
        0xE73A910B,
        0x158DC020,
        0x041E0008,
        0xE7C21243,
        0xE4B54010,
        0xE7676468,
    };
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

    var pc: u32 = 0;
    while (pc < test_data.len) : (pc += 1) {
        _ = try decodeInstr(&w, test_data[pc]);
    }

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

    var pc: u32 = 0;
    while (pc < test_data.len) : (pc += 1) {
        _ = try decodeInstr(&w, test_data[pc]);
    }

    try std.testing.expectEqualStrings(expected, buf[0..expected.len]);
}
