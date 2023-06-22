const std = @import("std");
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    OP_RETURN,
    OP_CONSTANT,
    OP_CONSTANT_LONG,
    OP_NEGATE,
    OP_ADD,
    // Could be removed if we use OP_NEGATE and OP_ADD instead in order to have a minimal set of opcodes.
    // But that would lead to more bytecode for subtracting and execution would be slower as well.
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_NULL,
    OP_TRUE,
    OP_FALSE,
    OP_NOT,
    OP_EQUAL,
    OP_GREATER,
    OP_LESS,
    OP_NOT_EQUAL,
    OP_GREATER_EQUAL,
    OP_LESS_EQUAL,
    OP_PRINT,
    OP_POP,
    OP_DEFINE_GLOBAL,
    OP_DEFINE_GLOBAL_LONG,
    OP_GET_GLOBAL,
    OP_GET_GLOBAL_LONG,
    OP_SET_GLOBAL,
    OP_SET_GLOBAL_LONG,
    OP_GET_LOCAL,
    OP_SET_LOCAL,
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

// Disassembles all the instructions in the chunk
pub fn disassemble(self: *Chunk) void {
    var offset: u32 = 0;
    std.debug.print("Chunk size {}\n", .{self.byte_code.items.len});
    while (offset < self.byte_code.items.len) {
        std.debug.print("{X:04} ", .{offset});
        self.disassembleInstruction(&offset);
    }
}

// Disassembles a single instruction in the chunk
pub fn disassembleInstruction(self: *Chunk, offset: *u32) void {
    switch (@intToEnum(OpCode, self.byte_code.items[offset.*])) {
        .OP_RETURN => simpleInstruction("OP_RETURN\n"),
        .OP_CONSTANT => self.constantInstruction("OP_CONSTANT", offset),
        .OP_CONSTANT_LONG => self.longConstantInstruction("OP_CONSTANT_LONG", offset),
        .OP_NEGATE => simpleInstruction("OP_NEGATE\n"),
        .OP_ADD => simpleInstruction("OP_ADD\n"),
        .OP_SUBTRACT => simpleInstruction("OP_SUBTRACT\n"),
        .OP_MULTIPLY => simpleInstruction("OP_MULTIPLY"),
        .OP_DIVIDE => simpleInstruction("OP_DIVIDE"),
        .OP_NULL => simpleInstruction("OP_NULL"),
        .OP_TRUE => simpleInstruction("OP_TRUE"),
        .OP_FALSE => simpleInstruction("OP_FALSE"),
        .OP_NOT => simpleInstruction("OP_NOT"),
        .OP_EQUAL => simpleInstruction("OP_EQUAL"),
        .OP_GREATER => simpleInstruction("OP_GREATER"),
        .OP_LESS => simpleInstruction("OP_LESS"),
        .OP_NOT_EQUAL => simpleInstruction("OP_NOT_EQUAL"),
        .OP_GREATER_EQUAL => simpleInstruction("OP_GREATER_EQUAL"),
        .OP_LESS_EQUAL => simpleInstruction("OP_LESS_EQUAL"),
        .OP_PRINT => simpleInstruction("OP_PRINT"),
        .OP_POP => simpleInstruction("OP_POP"),
        .OP_DEFINE_GLOBAL => self.constantInstruction("OP_DEFINE_GLOBAL", offset),
        .OP_DEFINE_GLOBAL_LONG => self.longConstantInstruction("OP_DEFINE_GLOBAL_LONG", offset),
        .OP_GET_GLOBAL => self.constantInstruction("OP_GET_GLOBAL", offset),
        .OP_GET_GLOBAL_LONG => self.longConstantInstruction("OP_GET_GLOBAL_LONG", offset),
        .OP_SET_GLOBAL => self.constantInstruction("OP_SET_GLOBAL", offset),
        .OP_SET_GLOBAL_LONG => self.longConstantInstruction("OP_SET_GLOBAL_LONG", offset),
        .OP_GET_LOCAL => self.constantInstruction("OP_GET_LOCAL", offset),
        .OP_SET_LOCAL => self.constantInstruction("OP_SET_LOCAL", offset),
    }
    offset.* += 1;
}

fn simpleInstruction(name: []const u8) void {
    std.debug.print("{s}\n", .{name});
}

fn constantInstruction(self: *Chunk, name: []const u8, offset: *u32) void {
    var constantIndex: u8 = self.byte_code.items[offset.* + 1];
    std.debug.print("{s} {d} '", .{ name, constantIndex });
    self.values.items[constantIndex].printDebug();
    std.debug.print("\n", .{});
    offset.* += 1;
}

fn longConstantInstruction(self: *Chunk, name: []const u8, offset: *u32) void {
    var constantIndex: u24 = @intCast(u24, self.byte_code.items[offset.* + 1]) << 16;
    constantIndex |= @intCast(u24, self.byte_code.items[offset.* + 2]) << 8;
    constantIndex |= @intCast(u24, self.byte_code.items[offset.* + 3]);
    std.debug.print("{s} {d} '", .{ name, constantIndex });
    self.values.items[constantIndex].printDebug();
    std.debug.print("\n", .{});
    offset.* += 3;
}
