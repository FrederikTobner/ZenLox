const std = @import("std");
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    OP_RETURN,
    OP_CONSTANT,
    OP_CONSTANT_LONG,
    OP_NEGATE,
    OP_ADD,
    // Could be removed if we use OP_NEGATE and OP_ADD instead in order to have a minimal set of opcodes.
    // But that would make the bytecode bigger. And execution slower as well.
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
};

const Chunk = @This();
byte_code: std.ArrayList(u8),
lines: std.ArrayList(u32),
values: std.ArrayList(Value),

// Initializes a new chunk
pub fn init(allocator: std.mem.Allocator) Chunk {
    return Chunk{
        .byte_code = std.ArrayList(u8).init(allocator),
        .lines = std.ArrayList(u32).init(allocator),
        .values = std.ArrayList(Value).init(allocator),
    };
}

// Appends an opcode to the chunk
pub fn writeOpCode(self: *Chunk, byte: OpCode, line: u32) !void {
    try self.lines.append(line);
    try self.byte_code.append(@enumToInt(byte));
}

// Appends a byte to the chunk
pub fn writeByte(self: *Chunk, byte: u8, line: u32) !void {
    try self.lines.append(line);
    try self.byte_code.append(byte);
}

// Appends a 24 bit unsigned integer to the chunk (also called sword, for short word)
pub fn writeShortWord(self: *Chunk, sword: u24, line: u32) !void {
    const shiftValues = [_]u8{ 16, 8, 0 };
    for (shiftValues) |shift| {
        try self.writeByte(@intCast(u8, sword >> shift), line);
    }
}

// Adds a constant to the chunk
pub fn addConstant(self: *Chunk, value: Value) !void {
    try self.values.append(value);
}

// Deinitializes the chunk
pub fn deinit(self: *Chunk) void {
    self.byte_code.deinit();
    self.lines.deinit();
    self.values.deinit();
}

// Disassembles all the instructions in the chunk
pub fn disassembleChunk(self: *Chunk) void {
    var offset: u32 = 0;
    std.debug.print("Chunk size {}\n", .{self.byte_code.items.len});
    while (offset < self.byteCode.items.len) {
        std.debug.print("{X:04} ", .{offset});
        self.disassembleInstruction(&offset);
    }
}

// Disassembles a single instruction in the chunk
pub fn disassembleInstruction(self: *Chunk, offset: *u32) void {
    switch (@intToEnum(OpCode, self.byte_code.items[offset.*])) {
        OpCode.OP_RETURN => std.debug.print("OP_RETURN\n", .{}),
        OpCode.OP_CONSTANT => {
            var constantIndex: u8 = self.byte_code.items[offset.* + 1];
            std.debug.print("OP_CONSTANT {d} '", .{constantIndex});
            self.values.items[constantIndex].printDebug();
            std.debug.print("'\n", .{});
            offset.* += 1;
        },
        OpCode.OP_CONSTANT_LONG => {
            var constantIndex: u24 = @intCast(u24, self.byte_code.items[offset.* + 1]) << 16;
            constantIndex |= @intCast(u24, self.byte_code.items[offset.* + 2]) << 8;
            constantIndex |= @intCast(u24, self.byte_code.items[offset.* + 3]);
            std.debug.print("OP_CONSTANT_LONG {d} '", .{constantIndex});
            self.values.items[constantIndex].printDebug();
            std.debug.print("'\n", .{});
            offset.* += 3;
        },
        OpCode.OP_NEGATE => std.debug.print("OP_NEGATE\n", .{}),
        OpCode.OP_ADD => std.debug.print("OP_ADD\n", .{}),
        OpCode.OP_SUBTRACT => std.debug.print("OP_SUBTRACT\n", .{}),
        OpCode.OP_MULTIPLY => std.debug.print("OP_MULTIPLY\n", .{}),
        OpCode.OP_DIVIDE => std.debug.print("OP_DIVIDE\n", .{}),
    }
    offset.* += 1;
}
