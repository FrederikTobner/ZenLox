const std = @import("std");
const Chunk = @import("chunk.zig");
const OpCode = @import("chunk.zig").OpCode;

// Disassembles all the instructions in the chunk
pub fn disassemble(chunk: *Chunk) void {
    var instruction_index: u32 = 0;
    std.debug.print("Chunk size {}\n", .{chunk.byte_code.items.len});
    while (instruction_index < chunk.byte_code.items.len) {
        std.debug.print("{X:04} ", .{instruction_index});
        disassembleInstruction(chunk, &instruction_index);
    }
}

// Disassembles a single instruction in the chunk
pub fn disassembleInstruction(chunk: *Chunk, instruction_index: *u32) void {
    const instruction: OpCode = @enumFromInt(chunk.byte_code.items[instruction_index.*]);
    switch (instruction) {
        .OP_ADD => simpleInstruction("OP_ADD"),
        .OP_CALL => constantInstruction(chunk, "OP_CALL", instruction_index, 0),
        .OP_CLOSE_UPVALUE => simpleInstruction("OP_CLOSE_UPVALUE"),
        .OP_CLOSURE => {
            instruction_index.* += 1;
            var constantIndex: u8 = chunk.byte_code.items[instruction_index.*];
            std.debug.print("OP_CLOSURE {d} ", .{constantIndex});
            chunk.values.items[constantIndex].printDebug();
        },
        .OP_CONSTANT => constantInstruction(chunk, "OP_CONSTANT", instruction_index, 0),
        .OP_CONSTANT_LONG => longConstantInstruction(chunk, "OP_CONSTANT_LONG", instruction_index, 0),
        .OP_DEFINE_GLOBAL => constantInstruction(chunk, "OP_DEFINE_GLOBAL", instruction_index, 0),
        .OP_DEFINE_GLOBAL_LONG => longConstantInstruction(chunk, "OP_DEFINE_GLOBAL_LONG", instruction_index, 0),
        .OP_DIVIDE => simpleInstruction("OP_DIVIDE"),
        .OP_EQUAL => simpleInstruction("OP_EQUAL"),
        .OP_FALSE => simpleInstruction("OP_FALSE"),
        .OP_GET_GLOBAL => constantInstruction(chunk, "OP_GET_GLOBAL", instruction_index, 0),
        .OP_GET_GLOBAL_LONG => longConstantInstruction(chunk, "OP_GET_GLOBAL_LONG", instruction_index, 0),
        .OP_GET_LOCAL => constantInstruction(chunk, "OP_GET_LOCAL", instruction_index, 1),
        .OP_GET_UPVALUE => constantInstruction(chunk, "OP_GET_UPVALUE", instruction_index, 0),
        .OP_GREATER => simpleInstruction("OP_GREATER"),
        .OP_GREATER_EQUAL => simpleInstruction("OP_GREATER_EQUAL"),
        .OP_JUMP => jumpInstruction(chunk, "OP_JUMP", 1, instruction_index),
        .OP_JUMP_IF_FALSE => jumpInstruction(chunk, "OP_JUMP_IF_FALSE", 1, instruction_index),
        .OP_LESS => simpleInstruction("OP_LESS"),
        .OP_LESS_EQUAL => simpleInstruction("OP_LESS_EQUAL"),
        .OP_LOOP => jumpInstruction(chunk, "OP_LOOP", -1, instruction_index),
        .OP_MULTIPLY => simpleInstruction("OP_MULTIPLY"),
        .OP_NEGATE => simpleInstruction("OP_NEGATE"),
        .OP_NOT => simpleInstruction("OP_NOT"),
        .OP_NOT_EQUAL => simpleInstruction("OP_NOT_EQUAL"),
        .OP_NULL => simpleInstruction("OP_NULL"),
        .OP_POP => simpleInstruction("OP_POP"),
        .OP_PRINT => simpleInstruction("OP_PRINT"),
        .OP_RETURN => simpleInstruction("OP_RETURN"),
        .OP_SET_GLOBAL => constantInstruction(chunk, "OP_SET_GLOBAL", instruction_index, 0),
        .OP_SET_GLOBAL_LONG => longConstantInstruction(chunk, "OP_SET_GLOBAL_LONG", instruction_index, 0),
        .OP_SET_LOCAL => constantInstruction(chunk, "OP_SET_LOCAL", instruction_index, 1),
        .OP_SET_UPVALUE => constantInstruction(chunk, "OP_SET_UPVALUE", instruction_index, 0),
        .OP_SUBTRACT => simpleInstruction("OP_SUBTRACT"),
        .OP_TRUE => simpleInstruction("OP_TRUE"),
    }
    instruction_index.* += 1;
}

/// Disassembles a simple instruction
fn simpleInstruction(name: []const u8) void {
    std.debug.print("{s}\n", .{name});
}

/// Disassembles a constant instruction
fn constantInstruction(chunk: *Chunk, name: []const u8, instruction_index: *u32, comptime offset: u1) void {
    var constantIndex: u8 = chunk.byte_code.items[instruction_index.* + 1];
    std.debug.print("{s} {d} '", .{ name, constantIndex - offset });
    chunk.values.items[constantIndex - offset].printDebug();
    std.debug.print("'\n", .{});
    instruction_index.* += 1;
}

/// Disassembles a long constant instruction
fn longConstantInstruction(chunk: *Chunk, name: []const u8, instruction_index: *u32, comptime offset: i8) void {
    var constantIndex: u24 = @as(u24, chunk.byte_code.items[instruction_index.* + 1]) << 16;
    constantIndex |= @as(u24, chunk.byte_code.items[instruction_index.* + 2]) << 8;
    constantIndex |= @as(u24, chunk.byte_code.items[instruction_index.* + 3]);
    std.debug.print("{s} {d} '", .{ name, constantIndex - offset });
    chunk.values.items[constantIndex - offset].printDebug();
    std.debug.print("'\n", .{});
    instruction_index.* += 3;
}

/// Disassembles a jump instruction
fn jumpInstruction(chunk: *Chunk, name: []const u8, sign: i8, instruction_index: *u32) void {
    var jump: u16 = @as(u16, chunk.byte_code.items[instruction_index.* + 1]) << 8;
    jump |= @as(u16, chunk.byte_code.items[instruction_index.* + 2]);
    std.debug.print("{s} {X} -> {X}\n", .{ name, instruction_index.* + 3, instruction_index.* + 3 + @as(i33, sign) * jump });
    instruction_index.* += 2;
}
