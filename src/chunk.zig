const std = @import("std");
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    OP_ADD,
    OP_CONSTANT,
    OP_CONSTANT_LONG,
    OP_DEFINE_GLOBAL,
    OP_DEFINE_GLOBAL_LONG,
    OP_DIVIDE,
    OP_EQUAL,
    OP_FALSE,
    OP_GET_GLOBAL,
    OP_GET_GLOBAL_LONG,
    OP_GET_LOCAL,
    OP_GREATER,
    OP_GREATER_EQUAL,
    OP_JUMP,
    OP_JUMP_IF_FALSE,
    OP_LESS,
    OP_LESS_EQUAL,
    OP_LOOP,
    OP_MULTIPLY,
    OP_NEGATE,
    OP_NOT,
    OP_NOT_EQUAL,
    OP_NULL,
    OP_RETURN,
    OP_POP,
    OP_PRINT,
    OP_SET_GLOBAL,
    OP_SET_GLOBAL_LONG,
    OP_SET_LOCAL,
    OP_SUBTRACT,
    OP_TRUE,
};

const Chunk = @This();
byte_code: std.ArrayList(u8),
lines: std.ArrayList(u32),
values: std.ArrayList(Value),

// Initializes a new chunk
// Every chunk needs to be deinitialized with `deinit` after it's no longer needed
pub fn init(allocator: std.mem.Allocator) Chunk {
    return Chunk{
        .byte_code = std.ArrayList(u8).init(allocator),
        .lines = std.ArrayList(u32).init(allocator),
        .values = std.ArrayList(Value).init(allocator),
    };
}

// Deinitializes the chunk
pub fn deinit(self: *Chunk) void {
    self.byte_code.deinit();
    self.lines.deinit();
    self.values.deinit();
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
pub fn addConstant(self: *Chunk, value: Value) !usize {
    try self.values.append(value);
    return self.values.items.len - 1;
}
