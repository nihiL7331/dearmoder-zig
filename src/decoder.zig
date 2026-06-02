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

fn print_data_instr(instr: DataInstr) void {
    switch (instr.opcode) {
        0b1000...0b1011 => {
            std.debug.print("{s}{s} {d}, {d}\n", .{ data_opcodes[instr.opcode], conds[instr.cond], instr.rn, instr.rm });
        },
        0b1101, 0b1111 => {
            std.debug.print("{s}{s} {d}, {d}\n", .{ data_opcodes[instr.opcode], conds[instr.cond], instr.rd, instr.rm });
        },
        else => {
            std.debug.print("{s}{s} {d}, {d}, {d}\n", .{ data_opcodes[instr.opcode], conds[instr.cond], instr.rd, instr.rn, instr.rm });
        },
    }
}

fn print_branch_instr(instr: BranchInstr) void {
    const opcode = if (instr.l == 1) "BL" else "B";

    const sgn_off: i32 = @as(i24, @bitCast(instr.offset));
    const byte_off = sgn_off * 4 + 8;

    if (byte_off >= 0) {
        std.debug.print("{s}{s} .+0x{x}\n", .{ opcode, conds[instr.cond], byte_off });
    } else {
        std.debug.print("{s}{s} .-0x{x}\n", .{ opcode, conds[instr.cond], -byte_off });
    }
}

fn print_sdt_instr(instr: SingleInstr) void {
    const opcode = if (instr.l == 1) "LDR" else "STR";

    std.debug.print("{s}{s}{s}{s} R{d}, ", .{ opcode, conds[instr.cond], if (instr.b == 1) "B" else "", if (instr.p == 0 and instr.w == 1) "T" else "", instr.rd });

    std.debug.print("[R{d}", .{instr.rn});

    if (instr.p == 0) {
        std.debug.print("]", .{});
    }

    if (instr.i == 1) {
        const offset: SingleOffset = @bitCast(instr.offset);
        std.debug.print(", {s}R{d}", .{ if (instr.u == 1) "" else "-", offset.rm });
    } else {
        std.debug.print(", #{s}{d}", .{ if (instr.u == 1) "" else "-", instr.offset });
    }

    if (instr.p == 1) {
        std.debug.print("]", .{});

        if (instr.w == 1) {
            std.debug.print("!", .{});
        }
    }

    std.debug.print("\n", .{});
}

pub fn decode(data: []const u32) !void {
    var pc: usize = 0;
    while (pc != data.len) : (pc += 1) {
        const id: u3 = @truncate((data[pc] >> 25) & 0b111);

        switch (id) {
            0b000, 0b001 => {
                const instr: DataInstr = @bitCast(data[pc]);
                print_data_instr(instr);
            },
            0b101 => {
                const instr: BranchInstr = @bitCast(data[pc]);
                print_branch_instr(instr);
            },
            0b010, 0b011 => {
                const instr: SingleInstr = @bitCast(data[pc]);
                print_sdt_instr(instr);
            },
            else => {
                std.debug.print("Unimplemented block\n", .{});
            },
        }
    }
}
