const std = @import("std");
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    OP_RETURN,
    OP_CONSTANT,
};

pub const Chunk = struct {
    code: std.ArrayList(OpCode),
    lines: std.ArrayList(u32),
    values: std.ArrayList(Value),
    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = std.ArrayList(OpCode).init(allocator),
            .lines = std.ArrayList(u32).init(allocator),
            .values = std.ArrayList(Value).init(allocator),
        };
    }

    pub fn writeOpCode(self: *Chunk, byte: OpCode, line: u32) !void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn writeByte(self: *Chunk, byte: u8, line: u32) !void {
        try self.code.append(@intToEnum(OpCode, byte));
        try self.lines.append(line);
    }

    pub fn addConstant(self: *Chunk, value: Value) !void {
        try self.values.append(value);
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        self.lines.deinit();
        self.values.deinit();
    }

    pub fn disassembleChunk(self: *Chunk, stdout: anytype) !void {
        var offset: u32 = 0;
        while (offset < self.code.items.len) {
            try stdout.print("{X:04} ", .{offset});
            try self.disassembleInstruction(&offset, stdout);
        }
    }

    pub fn disassembleInstruction(self: *Chunk, offset: *u32, stdout: anytype) !void {
        switch (self.code.items[offset.*]) {
            OpCode.OP_RETURN => {
                try stdout.print("OP_RETURN\n", .{});
            },
            OpCode.OP_CONSTANT => {
                var constantIndex: u8 = @enumToInt(self.code.items[offset.* + 1]);
                try stdout.print("OP_CONSTANT {d} '{}'\n", .{ constantIndex, self.values.items[constantIndex] });
                offset.* += 1;
            },
        }
        offset.* += 1;
    }
};
