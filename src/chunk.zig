const std = @import("std");
const Value = @import("./value.zig").Value;

pub const OpCode = enum(u8) {
    OP_RETURN,
};

pub const Chunk = struct {
    code: std.ArrayList(OpCode),
    lines: std.ArrayList(u32),
    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = std.ArrayList(OpCode).init(allocator),
            .lines = std.ArrayList(u32).init(allocator),
        };
    }
    pub fn writeOpCode(self: *Chunk, byte: OpCode, line: u32) !void {
        try self.code.append(byte);
        try self.lines.append(line);
    }
    pub fn deinit(self: *Chunk) void {
        self.code.deinit();
        self.lines.deinit();
    }
    pub fn disassembleChunk(self: *Chunk) void {
        var offset: u32 = 0;
        while (offset < self.code.items.len) : (offset += 1) {
            std.debug.print("{d:4} ", .{offset});
            self.disassembleInstruction(&offset);
        }
    }

    pub fn disassembleInstruction(self: *Chunk, offset: *u32) void {
        switch (self.code.items[offset.*]) {
            OpCode.OP_RETURN => {
                std.debug.print("OP_RETURN\n", .{});
                offset.* += 1;
            },
        }
    }
};
