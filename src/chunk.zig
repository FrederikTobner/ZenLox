const std = @import("std");
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    OP_RETURN,
    OP_CONSTANT,
    OP_CONSTANT_LONG,
};

// This struct will store the line number and the index of the first opcode in the chunk corresponding to that line.
// e.g. 1-0, 2-4, 3-5 and so on
const LineInfo = struct {
    line: u32,
    firstOpCodeIndex: u32,
};

pub const Chunk = struct {
    byteCode: std.ArrayList(OpCode),
    lines: std.ArrayList(LineInfo),
    values: std.ArrayList(Value),

    // Initializes a new chunk
    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .byteCode = std.ArrayList(OpCode).init(allocator),
            .lines = std.ArrayList(LineInfo).init(allocator),
            .values = std.ArrayList(Value).init(allocator),
        };
    }

    // Appends an opcode to the chunk
    pub fn writeOpCode(self: *Chunk, byte: OpCode, line: u32) !void {
        try self.handleLine(line);
        try self.byteCode.append(byte);
    }

    // Appends a byte to the chunk
    pub fn writeByte(self: *Chunk, byte: u8, line: u32) !void {
        try self.handleLine(line);
        try self.byteCode.append(@intToEnum(OpCode, byte));
    }

    // Appends a 24 bit unsigned integer to the chunk (also called sword, for short word)
    pub fn writeSWORD(self: *Chunk, sword: u24, line: u32) !void {
        try self.handleLine(line);
        try self.byteCode.append(@intToEnum(OpCode, sword >> 16));
        try self.byteCode.append(@intToEnum(OpCode, sword >> 8));
        try self.byteCode.append(@intToEnum(OpCode, sword));
    }

    // Adds the line info to the chunk
    fn handleLine(self: *Chunk, line: u32) !void {
        if (self.lines.items.len == 0) {
            try self.lines.append(LineInfo{ .line = line, .firstOpCodeIndex = 0 });
        } else if (self.lines.items[self.lines.items.len - 1].line != line) {
            try self.lines.append(LineInfo{ .line = line, .firstOpCodeIndex = @intCast(u32, self.byteCode.items.len) });
        }
    }

    // Adds a constant to the chunk
    pub fn addConstant(self: *Chunk, value: Value) !void {
        try self.values.append(value);
    }

    // Deinitializes the chunk
    pub fn deinit(self: *Chunk) void {
        self.byteCode.deinit();
        self.lines.deinit();
        self.values.deinit();
    }

    // Gets the line number corresponding to the offset
    pub fn getLine(self: *Chunk, offset: u32) u32 {
        var line: u32 = 0;
        for (self.lines.items) |lineInfo| {
            if (lineInfo.firstOpCodeIndex > offset) {
                break;
            }
            line = lineInfo.line;
        }
        return line;
    }

    // Disassembles all the instructions in the chunk
    pub fn disassembleChunk(self: *Chunk, stdout: anytype) !void {
        var offset: u32 = 0;
        while (offset < self.byteCode.items.len) {
            try stdout.print("{X:04} ", .{offset});
            try self.disassembleInstruction(&offset, stdout);
        }
    }

    // Disassembles a single instruction in the chunk
    pub fn disassembleInstruction(self: *Chunk, offset: *u32, stdout: anytype) !void {
        switch (self.byteCode.items[offset.*]) {
            OpCode.OP_RETURN => {
                try stdout.print("OP_RETURN\n", .{});
            },
            OpCode.OP_CONSTANT => {
                var constantIndex: u8 = @enumToInt(self.byteCode.items[offset.* + 1]);
                try stdout.print("OP_CONSTANT {d} '", .{constantIndex});
                try self.values.items[constantIndex].print(stdout);
                try stdout.print("'\n", .{});
                offset.* += 1;
            },
            OpCode.OP_CONSTANT_LONG => {
                var constantIndex: u24 = @intCast(u24, @enumToInt(self.byteCode.items[offset.* + 1])) << 16 | @intCast(u24, @enumToInt(self.byteCode.items[offset.* + 2])) << 8 | @intCast(u24, @enumToInt(self.byteCode.items[offset.* + 3]));
                try stdout.print("OP_CONSTANT_LONG {d} '", .{constantIndex});
                try self.values.items[constantIndex].print(stdout);
                try stdout.print("'\n", .{});
                offset.* += 3;
            },
        }
        offset.* += 1;
    }
};

test "Getting Line Info" {
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = generalPurposeAllocator.allocator();
    defer _ = generalPurposeAllocator.deinit();
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();
    try chunk.writeOpCode(OpCode.OP_RETURN, 1);
    try chunk.writeOpCode(OpCode.OP_CONSTANT, 1);
    try chunk.writeByte(0, 1);
    try chunk.writeOpCode(OpCode.OP_CONSTANT, 2);
    try chunk.writeByte(1, 2);
    try chunk.writeOpCode(OpCode.OP_CONSTANT, 3);
    try chunk.writeByte(2, 3);
    var index: u32 = 0;
    while (index < chunk.byteCode.items.len) : (index += 1) {
        switch (index) {
            0...2 => try std.testing.expectEqual(@intCast(u32, 1), chunk.getLine(index)),
            3...4 => try std.testing.expectEqual(@intCast(u32, 2), chunk.getLine(index)),
            5...6 => try std.testing.expectEqual(@intCast(u32, 3), chunk.getLine(index)),
            else => unreachable,
        }
    }
}
