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

const conds = [_][]const u8{
    "EQ", "NE", "CS", "CC", "MI", "PL", "VS", "VC",
    "HI", "LS", "GE", "LT", "GT", "LE", "", "", // 14 (AL) prints nothing
};

const s_types = [_][]const u8{
    "LSL", "LSR", "ASR", "ROR",
};

fn print_data_instr(writer: anytype, instr: DataInstr) !void {
    switch (instr.opcode) {
        0b1000...0b1011 => {
            try writer.print("{s}{s} R{d}, R{d}\n", .{ data_opcodes[instr.opcode], conds[instr.cond], instr.rn, instr.rm });
        },
        0b1101, 0b1111 => {
            try writer.print("{s}{s} R{d}, R{d}\n", .{ data_opcodes[instr.opcode], conds[instr.cond], instr.rd, instr.rm });
        },
        else => {
            try writer.print("{s}{s} R{d}, R{d}, R{d}\n", .{ data_opcodes[instr.opcode], conds[instr.cond], instr.rd, instr.rn, instr.rm });
        },
    }
}

fn print_branch_instr(writer: anytype, instr: BranchInstr) !void {
    const opcode = if (instr.l == 1) "BL" else "B";

    const sgn_off: i32 = @as(i24, @bitCast(instr.offset));
    const byte_off = sgn_off * 4 + 8;

    if (byte_off >= 0) {
        try writer.print("{s}{s} .+0x{x}\n", .{ opcode, conds[instr.cond], byte_off });
    } else {
        try writer.print("{s}{s} .-0x{x}\n", .{ opcode, conds[instr.cond], -byte_off });
    }
}

fn print_sdt_instr(writer: anytype, instr: SingleInstr) !void {
    const opcode = if (instr.l == 1) "LDR" else "STR";

    try writer.print("{s}{s}{s}{s} R{d}, ", .{ opcode, conds[instr.cond], if (instr.b == 1) "B" else "", if (instr.p == 0 and instr.w == 1) "T" else "", instr.rd });

    try writer.print("[R{d}", .{instr.rn});

    if (instr.p == 0) {
        try writer.print("]", .{});
    }

    if (instr.i == 1) {
        const offset: SingleOffset = @bitCast(instr.offset);

        try writer.print(", {s}R{d}", .{ if (instr.u == 1) "" else "-", offset.rm });
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
        try writer.print(", #{s}0x{x}", .{ if (instr.u == 1) "" else "-", instr.offset });
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
                try print_data_instr(writer, instr);
            },
            0b101 => {
                const instr: BranchInstr = @bitCast(data[pc]);
                try print_branch_instr(writer, instr);
            },
            0b010, 0b011 => {
                const instr: SingleInstr = @bitCast(data[pc]);
                try print_sdt_instr(writer, instr);
            },
            else => {
                try writer.print("Unimplemented block\n", .{});
            },
        }
    }
}
