const std = @import("std");

const arm = @import("arm.zig");
const thumb = @import("thumb.zig");

pub const Decoder = struct {
    const Self = @This();

    const InstrMode = enum { Arm, Thumb };
    mode: InstrMode,
    pc: u32,

    pub fn init(pc: u32, mode: InstrMode) Self {
        return .{
            .mode = mode,
            .pc = pc,
        };
    }

    pub fn decodeBlock(self: *Self, writer: anytype, data: []const u8) !void {
        while (true) {
            switch (self.mode) {
                .Arm => {
                    const instr_bytes = data[self.pc .. self.pc + 4];
                    const instr = std.mem.readInt(u32, instr_bytes[0..4], .little);

                    self.pc += 4;

                    if (try self.decodeArmInstr(writer, instr)) break;
                },
                .Thumb => {
                    std.debug.print("unimplemented", .{});
                },
            }
        }
    }

    fn decodeArmInstr(self: *Self, writer: anytype, instr: u32) !bool {
        if (try arm.decodeInstr(writer, instr)) |rel_off| {
            const target_addr = self.pc +% @as(u32, @bitCast(rel_off));

            self.pc = target_addr & ~@as(u32, 1);

            if (target_addr & 1 != 0) {
                self.mode = .Thumb;
            }

            return true;
        }

        return false;
    }
};
