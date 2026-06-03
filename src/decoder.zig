const std = @import("std");

const arm = @import("arm.zig");
const thumb = @import("thumb.zig");

pub const Decoder = struct {
    const Self = @This();

    const InstrMode = enum { Arm, Thumb };
    const BranchData = struct {
        pc: u32,
        mode: InstrMode,
    };

    allocator: std.mem.Allocator,
    todo: std.ArrayListUnmanaged(BranchData),
    mode: InstrMode = undefined,
    pc: u32 = undefined,

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .allocator = allocator,
            .todo = .empty,
        };
    }

    pub fn deinit(self: *Self) void {
        self.todo.deinit(self.allocator);
    }

    pub fn decodeAll(self: *Self, writer: anytype, data: []const u8, entry_pc: u32, entry_mode: InstrMode) !void {
        self.todo.clearRetainingCapacity();

        try self.todo.append(self.allocator, .{
            .pc = entry_pc,
            .mode = entry_mode,
        });

        while (self.jumpNextTodo()) {
            try self.decodeBlock(writer, data);
        }
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
        if (try arm.decodeInstr(writer, instr)) |branch_info| {
            const target_addr = self.pc +% @as(u32, @bitCast(branch_info.offset));

            if (branch_info.fall_reach) {
                try self.todo.append(self.allocator, .{
                    .pc = self.pc + 4,
                    .mode = self.mode,
                });
            }

            const is_thumb_switch = target_addr & 1 != 0;
            try self.todo.append(self.allocator, .{
                .pc = target_addr & ~@as(u32, 1),
                .mode = if (is_thumb_switch) .Thumb else .Arm,
            });

            return true;
        }

        return false;
    }

    fn jumpNextTodo(self: *Self) bool {
        if (self.todo.pop()) |next_path| {
            self.pc = next_path.pc;
            self.mode = next_path.mode;

            return true;
        }

        return false;
    }
};
