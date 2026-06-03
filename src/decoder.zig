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
        try writer.print("#0x{x}\n", .{instr.rm});
    } else {
        try writer.print("R{d}\n", .{instr.rm});
    }
}

fn printBranchInstr(writer: anytype, instr: BranchInstr) !void {
    const opcode = branch_opcodes[instr.l];

    const sgn_off: i32 = @as(i24, @bitCast(instr.offset));
    const byte_off = sgn_off * 4 + 8;

    if (byte_off >= 0) {
        try writer.print("{s}{s} .+0x{x}\n", .{ opcode, conds[instr.cond], byte_off });
    } else {
        try writer.print("{s}{s} .-0x{x}\n", .{ opcode, conds[instr.cond], -byte_off });
    }
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

pub fn decode(writer: anytype, data: []const u32) !void {
    var pc: usize = 0;
    while (pc != data.len) : (pc += 1) {
        const id: u3 = @truncate((data[pc] >> 25) & 0b111);

        switch (id) {
            0b000, 0b001 => {
                const instr: DataInstr = @bitCast(data[pc]);
                try printDataInstr(writer, instr);
            },
            0b101 => {
                const instr: BranchInstr = @bitCast(data[pc]);
                try printBranchInstr(writer, instr);
            },
            0b010, 0b011 => {
                const instr: SingleInstr = @bitCast(data[pc]);
                try printSdtInstr(writer, instr);
            },
            else => {
                try writer.print("Unimplemented block\n", .{});
            },
        }
    }
}
