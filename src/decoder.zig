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

const data_opcodes = [_][]const u8{
    "AND", "EOR", "SUB", "RSB", "ADD", "ADC", "SBC", "RSC",
    "TST", "TEQ", "CMP", "CMN", "ORR", "MOV", "BIC", "MVN",
};

pub fn decode(data: []const u32) !void {
    var pc: usize = 0;
    while (pc != data.len) : (pc += 1) {
        const id: u3 = @truncate((data[pc] >> 25) & 0b111);

        switch (id) {
            0b000, 0b001 => {
                const instr: DataInstr = @bitCast(data[pc]);
                std.debug.print("Data processing: ID={d}, OP={s}, I={d}, Rn={d}, Rd={d}, Rm={d}\n", .{ instr.id, data_opcodes[instr.opcode], instr.i, instr.rn, instr.rd, instr.rm });
            },
            0b101 => {
                const instr: BranchInstr = @bitCast(data[pc]);
                const opcode = if (instr.l == 1) "BL" else "B";

                std.debug.print("Branch: ID={d}, OP={s}, OFF={d}\n", .{ instr.id, opcode, instr.offset });
            },
            0b010, 0b011 => {
                const instr: SingleInstr = @bitCast(data[pc]);
                const opcode = if (instr.l == 1) "LDR" else "STR";

                std.debug.print("Single data transfer: ID={d}, OP={s}{s}, U={d}, Rn={d}, Rd={d}, OFF={d}\n", .{ instr.id, opcode, if (instr.b == 1) "B" else "", instr.u, instr.rn, instr.rd, instr.offset });
            },
            else => {
                std.debug.print("Unimplemented block\n", .{});
            },
        }
    }
}
