const std = @import("std");
const Chunk = @import("chunk.zig");
const OpCode = @import("chunk.zig").OpCode;

// Disassembles all the instructions in the chunk
pub fn disassemble(chunk: *Chunk) void {
    var offset: u32 = 0;
    std.debug.print("Chunk size {}\n", .{chunk.byte_code.items.len});
    while (offset < chunk.byte_code.items.len) {
        std.debug.print("{X:04} ", .{offset});
        disassembleInstruction(chunk, &offset);
    }
}

// Disassembles a single instruction in the chunk
pub fn disassembleInstruction(chunk: *Chunk, offset: *u32) void {
    switch (@intToEnum(OpCode, chunk.byte_code.items[offset.*])) {
        .OP_RETURN => simpleInstruction("OP_RETURN\n"),
        .OP_CONSTANT => constantInstruction(chunk, "OP_CONSTANT", offset),
        .OP_CONSTANT_LONG => longConstantInstruction(chunk, "OP_CONSTANT_LONG", offset),
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
        .OP_DEFINE_GLOBAL => constantInstruction(chunk, "OP_DEFINE_GLOBAL", offset),
        .OP_DEFINE_GLOBAL_LONG => longConstantInstruction(chunk, "OP_DEFINE_GLOBAL_LONG", offset),
        .OP_GET_GLOBAL => constantInstruction(chunk, "OP_GET_GLOBAL", offset),
        .OP_GET_GLOBAL_LONG => longConstantInstruction(chunk, "OP_GET_GLOBAL_LONG", offset),
        .OP_SET_GLOBAL => constantInstruction(chunk, "OP_SET_GLOBAL", offset),
        .OP_SET_GLOBAL_LONG => longConstantInstruction(chunk, "OP_SET_GLOBAL_LONG", offset),
        .OP_GET_LOCAL => constantInstruction(chunk, "OP_GET_LOCAL", offset),
        .OP_SET_LOCAL => constantInstruction(chunk, "OP_SET_LOCAL", offset),
        .OP_JUMP_IF_FALSE => constantInstruction(chunk, "OP_JUMP_IF_FALSE", offset),
        .OP_JUMP => constantInstruction(chunk, "OP_JUMP", offset),
    }
    offset.* += 1;
}

fn simpleInstruction(name: []const u8) void {
    std.debug.print("{s}\n", .{name});
}

fn constantInstruction(chunk: *Chunk, name: []const u8, offset: *u32) void {
    var constantIndex: u8 = chunk.byte_code.items[offset.* + 1];
    std.debug.print("{s} {d} '", .{ name, constantIndex });
    chunk.values.items[constantIndex].printDebug();
    std.debug.print("\n", .{});
    offset.* += 1;
}

fn longConstantInstruction(chunk: *Chunk, name: []const u8, offset: *u32) void {
    var constantIndex: u24 = @intCast(u24, chunk.byte_code.items[offset.* + 1]) << 16;
    constantIndex |= @intCast(u24, chunk.byte_code.items[offset.* + 2]) << 8;
    constantIndex |= @intCast(u24, chunk.byte_code.items[offset.* + 3]);
    std.debug.print("{s} {d} '", .{ name, constantIndex });
    chunk.values.items[constantIndex].printDebug();
    std.debug.print("\n", .{});
    offset.* += 3;
}

fn jumpInstruction(chunk: *Chunk, name: []const u8, sign: i8, offset: *u32) void {
    var jump: u16 = @intCast(u16, chunk.byte_code.items[offset.* + 1]) << 8;
    jump |= @intCast(u16, chunk.byte_code.items[offset.* + 2]);
    std.debug.print("{s} {d} -> {d}\n", .{ name, offset.* + 3, offset.* + 3 + sign * jump });
    offset.* += 2;
}