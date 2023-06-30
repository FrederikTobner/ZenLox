const std = @import("std");
const Chunk = @import("chunk.zig");
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const Compiler = @import("compiler.zig");
const Object = @import("object.zig").Object;
const ObjectString = @import("object.zig").ObjectString;
const ObjectType = @import("object.zig").ObjectType;
const MemoryMutator = @import("memory_mutator.zig");
const Disassembler = @import("disassembler.zig");

pub const InterpreterError = error{
    Compile_Error,
    Runtime_Error,
};
const STACK_MAX: u9 = 256;
const ValueStack = struct {
    stack: [STACK_MAX]Value = undefined,
    stack_top_index: u8 = 0,

    // Resets the stack to empty.
    fn resetStack(self: *ValueStack) void {
        self.stack_top_index = 0;
        var start_index: usize = 0;
        while (start_index < STACK_MAX) : (start_index += 1) {
            self.stack[start_index] = Value{ .VAL_NULL = undefined };
        }
    }
    // Pushes a value onto the stack.
    fn push(self: *ValueStack, value: Value) !void {
        if (self.stack_top_index >= STACK_MAX) {
            return InterpreterError.Runtime_Error;
        }
        self.stack[self.stack_top_index] = value;
        self.stack_top_index += 1;
    }

    // Pops a value from the stack.
    fn pop(self: *ValueStack) Value {
        self.stack_top_index -= 1;
        return self.stack[self.stack_top_index];
    }

    fn peek(self: *ValueStack, distance: u8) Value {
        return self.stack[self.stack_top_index - 1 - distance];
    }
};
const tests = true;
const VirtualMachine = @This();
chunk: Chunk,
instruction_index: u32 = 0,
trace_execution: bool = @import("debug_options").traceExecution,
values: ValueStack = undefined,
writer: *const std.fs.File.Writer,
memory_mutator: MemoryMutator = undefined,

pub fn init(writer: *const std.fs.File.Writer, allocator: std.mem.Allocator) VirtualMachine {
    var value_stack = ValueStack{};
    value_stack.resetStack();
    return VirtualMachine{
        .values = value_stack,
        .writer = writer,
        .memory_mutator = MemoryMutator.init(allocator),
        .chunk = Chunk.init(allocator),
    };
}

pub fn deinit(self: *VirtualMachine) void {
    try self.memory_mutator.deinit();
    self.chunk.deinit();
}

pub fn interpret(self: *VirtualMachine, source: []const u8) !void {
    var compiler = Compiler.init(&self.memory_mutator);
    if (try compiler.compile(source, &self.chunk)) {
        try self.run();
    } else {
        return InterpreterError.Compile_Error;
    }
}

fn binaryOperation(self: *VirtualMachine, op: OpCode) !void {
    var b: Value = self.values.pop();
    var a: Value = self.values.pop();
    if (a.isNumber() and b.isNumber()) {
        switch (op) {
            .OP_ADD => try self.values.push(Value{ .VAL_NUMBER = a.VAL_NUMBER + b.VAL_NUMBER }),
            .OP_SUBTRACT => try self.values.push(Value{ .VAL_NUMBER = a.VAL_NUMBER - b.VAL_NUMBER }),
            .OP_MULTIPLY => try self.values.push(Value{ .VAL_NUMBER = a.VAL_NUMBER * b.VAL_NUMBER }),
            .OP_DIVIDE => try self.values.push(Value{ .VAL_NUMBER = a.VAL_NUMBER / b.VAL_NUMBER }),
            .OP_GREATER => try self.values.push(Value{ .VAL_BOOL = a.VAL_NUMBER > b.VAL_NUMBER }),
            .OP_LESS => try self.values.push(Value{ .VAL_BOOL = a.VAL_NUMBER < b.VAL_NUMBER }),
            .OP_GREATER_EQUAL => try self.values.push(Value{ .VAL_BOOL = a.VAL_NUMBER >= b.VAL_NUMBER }),
            .OP_LESS_EQUAL => try self.values.push(Value{ .VAL_BOOL = a.VAL_NUMBER <= b.VAL_NUMBER }),
            else => unreachable,
        }
    } else {
        switch (op) {
            .OP_EQUAL => try self.values.push(Value{ .VAL_BOOL = a.isEqual(b) }),
            .OP_NOT_EQUAL => try self.values.push(Value{ .VAL_BOOL = !a.isEqual(b) }),
            .OP_ADD => {
                if (a.isObject() and b.isObject() and a.VAL_OBJECT.object_type == ObjectType.OBJ_STRING and b.VAL_OBJECT.object_type == ObjectType.OBJ_STRING) {
                    var a_string = a.VAL_OBJECT.as(ObjectString);
                    var b_string = b.VAL_OBJECT.as(ObjectString);
                    var new_string = try self.memory_mutator.concatenateStringObjects(a_string, b_string);
                    try self.values.push(new_string);
                } else {
                    std.debug.print("Operands must be two numbers or two strings, but are {s} and {s}.\n", .{ a.getPrintableType(), b.getPrintableType() });
                    return InterpreterError.Runtime_Error;
                }
            },
            else => {
                std.debug.print("Operands must be two numbers, but are {s} and {s}.\n", .{ a.getPrintableType(), b.getPrintableType() });
                return InterpreterError.Runtime_Error;
            },
        }
    }
}
fn run(self: *VirtualMachine) !void {
    while (self.instruction_index < self.chunk.byte_code.items.len) : (self.instruction_index += 1) {
        if (self.trace_execution) {
            var index_copy = self.instruction_index;
            Disassembler.disassembleInstruction(&self.chunk, &index_copy);
            try self.writer.print("stack: ", .{});
            var counter: u8 = 0;
            while (counter < self.values.stack_top_index) : (counter += 1) {
                try self.writer.print("[", .{});
                try self.values.stack[counter].print(self.writer);
                try self.writer.print("]", .{});
            }
            try std.io.getStdOut().writer().print("\n", .{});
        }
        switch (@intToEnum(OpCode, self.chunk.byte_code.items[self.instruction_index])) {
            .OP_CONSTANT => {
                self.instruction_index += 1;
                try self.values.push(self.chunk.values.items[self.chunk.byte_code.items[self.instruction_index]]);
            },
            .OP_CONSTANT_LONG => try self.values.push(self.chunk.values.items[self.readShortWord()]),
            .OP_RETURN => {
                self.instruction_index += 1;
                return;
            },
            .OP_NEGATE => try self.values.push(Value{ .VAL_NUMBER = -self.values.pop().VAL_NUMBER }),
            .OP_ADD => try self.binaryOperation(.OP_ADD),
            .OP_SUBTRACT => try self.binaryOperation(.OP_SUBTRACT),
            .OP_MULTIPLY => try self.binaryOperation(.OP_MULTIPLY),
            .OP_DIVIDE => try self.binaryOperation(.OP_DIVIDE),
            .OP_NULL => try self.values.push(Value{ .VAL_NULL = undefined }),
            .OP_TRUE => try self.values.push(Value{ .VAL_BOOL = true }),
            .OP_FALSE => try self.values.push(Value{ .VAL_BOOL = false }),
            .OP_NOT => try self.values.push(Value{ .VAL_BOOL = self.values.pop().isFalsey() }),
            .OP_EQUAL => try self.binaryOperation(.OP_EQUAL),
            .OP_GREATER => try self.binaryOperation(.OP_GREATER),
            .OP_LESS => try self.binaryOperation(.OP_LESS),
            .OP_NOT_EQUAL => try self.binaryOperation(.OP_NOT_EQUAL),
            .OP_GREATER_EQUAL => try self.binaryOperation(.OP_GREATER_EQUAL),
            .OP_LESS_EQUAL => try self.binaryOperation(.OP_LESS_EQUAL),
            .OP_PRINT => {
                try self.values.pop().print(self.writer);
                try self.writer.print("\n", .{});
            },
            .OP_POP => _ = self.values.pop(),
            .OP_DEFINE_GLOBAL => {
                self.instruction_index += 1;
                var name = self.chunk.values.items[self.chunk.byte_code.items[self.instruction_index]].VAL_OBJECT.as(ObjectString);
                _ = try self.memory_mutator.globals.set(name, self.values.peek(0));
                _ = self.values.pop();
            },
            .OP_DEFINE_GLOBAL_LONG => {
                var name_index: u24 = self.readShortWord();
                var name = self.chunk.values.items[name_index].VAL_OBJECT.as(ObjectString);
                _ = try self.memory_mutator.globals.set(name, self.values.peek(0));
                _ = self.values.pop();
            },
            .OP_GET_GLOBAL => {
                self.instruction_index += 1;
                var name = self.chunk.values.items[self.chunk.byte_code.items[self.instruction_index]].VAL_OBJECT.as(ObjectString);
                var value = self.memory_mutator.globals.get(name);
                if (value) |val| {
                    try self.values.push(val);
                } else {
                    std.debug.print("Undefined variable '", .{});
                    try name.print(self.writer);
                    std.debug.print("'.\n", .{});
                    return InterpreterError.Runtime_Error;
                }
            },
            .OP_GET_GLOBAL_LONG => {
                var name_index: u24 = self.readShortWord();
                var name = self.chunk.values.items[name_index].VAL_OBJECT.as(ObjectString);
                var value = self.memory_mutator.globals.get(name);
                if (value) |val| {
                    try self.values.push(val);
                } else {
                    std.debug.print("Undefined variable '", .{});
                    try name.print(self.writer);
                    std.debug.print("'.\n", .{});
                    return InterpreterError.Runtime_Error;
                }
            },
            .OP_SET_GLOBAL => {
                self.instruction_index += 1;
                var name = self.chunk.values.items[self.chunk.byte_code.items[self.instruction_index]].VAL_OBJECT.as(ObjectString);
                var value = self.values.peek(0);
                if (try self.memory_mutator.globals.set(name, value)) {
                    _ = self.memory_mutator.globals.delete(name);
                    std.debug.print("Undefined variable '", .{});
                    try name.print(self.writer);
                    std.debug.print("'.\n", .{});
                    return InterpreterError.Runtime_Error;
                }
            },
            .OP_SET_GLOBAL_LONG => {
                var name_index = self.readShortWord();
                self.instruction_index += 3;
                var name = self.chunk.values.items[name_index].VAL_OBJECT.as(ObjectString);
                var value = self.values.peek(0);
                if (try self.memory_mutator.globals.set(name, value)) {
                    _ = self.memory_mutator.globals.delete(name);
                    std.debug.print("Undefined variable '", .{});
                    try name.print(self.writer);
                    std.debug.print("'.\n", .{});
                    return InterpreterError.Runtime_Error;
                }
            },
            .OP_GET_LOCAL => {
                self.instruction_index += 1;
                var slot = @intCast(u8, self.chunk.byte_code.items[self.instruction_index]);
                try self.values.push(self.values.peek(slot));
            },
            .OP_SET_LOCAL => {
                self.instruction_index += 1;
                var slot = @intCast(u8, self.chunk.byte_code.items[self.instruction_index]);
                self.values.stack[slot] = self.values.peek(0);
            },
            .OP_JUMP_IF_FALSE => {
                var offset = self.readShort();
                if (self.values.peek(0).isFalsey()) {
                    self.instruction_index += offset;
                }
            },
            .OP_JUMP => {
                var offset = self.readShort();
                self.instruction_index += offset;
            },
            .OP_LOOP => {
                var offset = self.readShort();
                self.instruction_index -= offset;
            },
        }
    }
    return;
}

fn readString(self: *VirtualMachine) *ObjectString {
    return self.chunk.values.items[self.chunk.byte_code.items[self.instruction_index]].as(ObjectString);
}

fn readShort(self: *VirtualMachine) u16 {
    var short = @intCast(u16, self.chunk.byte_code.items[self.instruction_index + 1]) << 8;
    short |= @intCast(u16, self.chunk.byte_code.items[self.instruction_index + 2]);
    self.instruction_index += 2;
    return short;
}

fn readShortWord(self: *VirtualMachine) u24 {
    var short_word = @intCast(u24, self.chunk.byte_code.items[self.instruction_index + 1]) << 16;
    short_word |= @intCast(u24, self.chunk.byte_code.items[self.instruction_index + 2]) << 8;
    short_word |= @intCast(u24, self.chunk.byte_code.items[self.instruction_index + 3]);
    self.instruction_index += 3;
    return short_word;
}
