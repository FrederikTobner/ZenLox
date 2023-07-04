const std = @import("std");

const Chunk = @import("chunk.zig");
const Compiler = @import("compiler.zig");
const Disassembler = @import("disassembler.zig");
const MemoryMutator = @import("memory_mutator.zig");
const Object = @import("object.zig").Object;
const ObjectString = @import("object.zig").ObjectString;
const ObjectFunction = @import("object.zig").ObjectFunction;
const ObjectType = @import("object.zig").ObjectType;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;

/// The possible errors that can occur during interpretation.
pub const InterpreterError = error{
    CompileError,
    RuntimeError,
};

/// Models a call frame of the virtual machine.
const CallFrame = struct {
    function: *ObjectFunction,
    instruction_index: u32 = undefined,
    slots: [*]Value,
    pub fn init(function: *ObjectFunction, slots: [*]Value, instruction_index: u32) CallFrame {
        return CallFrame{
            .slots = slots,
            .function = function,
            .instruction_index = instruction_index,
        };
    }
};

/// The maximum number of call frames that can be active at once.
const CALL_FRAME_MAX: u7 = 64;
/// The maximum number of values that can be on the stack at once.
const STACK_MAX: u15 = 256 * @intCast(u15, CALL_FRAME_MAX);

/// The value stack of the virtual machine.
const ValueStack = struct {
    items: [STACK_MAX]Value = undefined,
    stack_top: [*]Value = undefined,

    /// Resets the stack to empty.
    fn resetStack(self: *ValueStack) void {
        self.stack_top = self.items[0..];
    }
    /// Pushes a value onto the stack.
    fn push(self: *ValueStack, value: Value) !void {
        if (@ptrToInt(self.stack_top) > @ptrToInt(&self.items[STACK_MAX - 1])) {
            return InterpreterError.RuntimeError;
        }
        self.stack_top[0] = value;
        self.stack_top += 1;
    }

    /// Pops a value from the stack.
    fn pop(self: *ValueStack) Value {
        self.stack_top -= 1;
        return self.stack_top[0];
    }

    /// Peeks at a value from the stack with the given distance.
    fn peek(self: *ValueStack, distance: u14) Value {
        return (self.stack_top - 1 - distance)[0];
    }
};

/// The virtual machine struct.
const VirtualMachine = @This();
/// The call frames for the virtual machine.
call_frames: [CALL_FRAME_MAX]CallFrame = undefined,
/// Frame counter for the call frames.
frame_count: u6 = 0,
/// Boolean to determine if the virtual machine should trace execution.
trace_execution: bool = @import("debug_options").traceExecution,
/// The value stack for the virtual machine.
value_stack: ValueStack,
/// The writer for the virtual machine. Writes to stdout.
writer: *const std.fs.File.Writer,
/// The memory mutator used by the virtual machine.
memory_mutator: *MemoryMutator,
/// The compiler used by the virtual machine.
compiler: Compiler,

pub fn init(writer: *const std.fs.File.Writer, memory_mutator: *MemoryMutator) !VirtualMachine {
    var value_stack = ValueStack{};
    value_stack.resetStack();
    return VirtualMachine{
        .value_stack = value_stack,
        .writer = writer,
        .memory_mutator = memory_mutator,
        .compiler = try Compiler.init(memory_mutator),
    };
}

pub fn deinit(self: *VirtualMachine) void {
    try self.memory_mutator.deinit();
}

pub fn interpret(self: *VirtualMachine, source: []const u8) !void {
    const function = try self.compiler.compile(source);
    if (function) |fun| {
        try self.value_stack.push(Value{ .VAL_OBJECT = &fun.object });
        self.call_frames[self.frame_count] = CallFrame.init(fun, self.value_stack.stack_top, if (self.frame_count == 0) 0 else self.call_frames[self.frame_count - 1].instruction_index);
        self.frame_count = 1;
        try self.run();
    } else {
        return InterpreterError.CompileError;
    }
}

fn binaryOperation(self: *VirtualMachine, comptime op: OpCode) !void {
    var b: Value = self.value_stack.pop();
    var a: Value = self.value_stack.pop();
    if (a.is(.VAL_NUMBER) and b.is(.VAL_NUMBER)) {
        switch (op) {
            .OP_ADD => try self.value_stack.push(Value{ .VAL_NUMBER = a.VAL_NUMBER + b.VAL_NUMBER }),
            .OP_SUBTRACT => try self.value_stack.push(Value{ .VAL_NUMBER = a.VAL_NUMBER - b.VAL_NUMBER }),
            .OP_MULTIPLY => try self.value_stack.push(Value{ .VAL_NUMBER = a.VAL_NUMBER * b.VAL_NUMBER }),
            .OP_DIVIDE => try self.value_stack.push(Value{ .VAL_NUMBER = a.VAL_NUMBER / b.VAL_NUMBER }),
            .OP_GREATER => try self.value_stack.push(Value{ .VAL_BOOL = a.VAL_NUMBER > b.VAL_NUMBER }),
            .OP_LESS => try self.value_stack.push(Value{ .VAL_BOOL = a.VAL_NUMBER < b.VAL_NUMBER }),
            .OP_GREATER_EQUAL => try self.value_stack.push(Value{ .VAL_BOOL = a.VAL_NUMBER >= b.VAL_NUMBER }),
            .OP_LESS_EQUAL => try self.value_stack.push(Value{ .VAL_BOOL = a.VAL_NUMBER <= b.VAL_NUMBER }),
            else => unreachable,
        }
    } else {
        switch (op) {
            .OP_EQUAL => try self.value_stack.push(Value{ .VAL_BOOL = a.isEqual(b) }),
            .OP_NOT_EQUAL => try self.value_stack.push(Value{ .VAL_BOOL = !a.isEqual(b) }),
            .OP_ADD => {
                if (a.is(.VAL_OBJECT) and b.is(.VAL_OBJECT) and a.VAL_OBJECT.object_type == ObjectType.OBJ_STRING and b.VAL_OBJECT.object_type == ObjectType.OBJ_STRING) {
                    var a_string = a.VAL_OBJECT.as(ObjectString);
                    var b_string = b.VAL_OBJECT.as(ObjectString);
                    var new_string = try self.memory_mutator.concatenateStringObjects(a_string, b_string);
                    try self.value_stack.push(new_string);
                } else {
                    return self.reportRunTimeError("Operands must be two numbers or two strings, but are {s} and {s}.\n", .{ a.getPrintableType(), b.getPrintableType() });
                }
            },
            else => {
                return self.reportRunTimeError("Operands must be two numbers, but are {s} and {s}.\n", .{ a.getPrintableType(), b.getPrintableType() });
            },
        }
    }
}

/// Runs the bytecode in the chunk.
fn run(self: *VirtualMachine) !void {
    while (true) : (self.currentFrame().instruction_index += 1) {
        if (self.trace_execution) {
            try self.traceExecution();
        }
        switch (@intToEnum(OpCode, self.currentChunk().byte_code.items[self.currentFrame().instruction_index])) {
            .OP_ADD => try self.binaryOperation(.OP_ADD),
            .OP_CALL => {
                var arg_count = self.currentChunk().byte_code.items[self.currentFrame().instruction_index + 1];
                self.currentFrame().instruction_index += 1;
                _ = try self.callValue((self.value_stack.stack_top - arg_count - 1)[0], arg_count);
            },
            .OP_CONSTANT => {
                self.currentFrame().instruction_index += 1;
                try self.value_stack.push(self.currentChunk().values.items[self.currentChunk().byte_code.items[self.currentFrame().instruction_index]]);
            },
            .OP_CONSTANT_LONG => try self.value_stack.push(self.currentChunk().values.items[self.readShortWord()]),
            .OP_DEFINE_GLOBAL => {
                self.currentFrame().instruction_index += 1;
                try self.defineGlobal(self.currentChunk().values.items[self.currentChunk().byte_code.items[self.currentFrame().instruction_index]].VAL_OBJECT.as(ObjectString));
            },
            .OP_DEFINE_GLOBAL_LONG => {
                var name_index: u24 = self.readShortWord();
                try self.defineGlobal(self.currentChunk().values.items[name_index].VAL_OBJECT.as(ObjectString));
            },
            .OP_DIVIDE => try self.binaryOperation(.OP_DIVIDE),
            .OP_EQUAL => try self.binaryOperation(.OP_EQUAL),
            .OP_FALSE => try self.value_stack.push(Value{ .VAL_BOOL = false }),
            .OP_GET_GLOBAL => {
                self.currentFrame().instruction_index += 1;
                try self.getGlobal(self.currentChunk().values.items[self.currentChunk().byte_code.items[self.currentFrame().instruction_index]].VAL_OBJECT.as(ObjectString));
            },
            .OP_GET_GLOBAL_LONG => {
                const name_index = self.readShortWord();
                try self.getGlobal(self.currentChunk().values.items[name_index].VAL_OBJECT.as(ObjectString));
            },
            .OP_GET_LOCAL => {
                self.currentFrame().instruction_index += 1;
                const slot = @intCast(u8, self.currentChunk().byte_code.items[self.currentFrame().instruction_index]);
                try self.value_stack.push(self.value_stack.peek(slot));
            },
            .OP_GREATER => try self.binaryOperation(.OP_GREATER),
            .OP_GREATER_EQUAL => try self.binaryOperation(.OP_GREATER_EQUAL),
            .OP_JUMP => {
                const offset = self.readShort();
                self.currentFrame().instruction_index += offset;
            },
            .OP_JUMP_IF_FALSE => {
                const offset = self.readShort();
                if (self.value_stack.peek(0).isFalsey()) {
                    self.currentFrame().instruction_index += offset;
                }
            },
            .OP_LESS => try self.binaryOperation(.OP_LESS),
            .OP_LESS_EQUAL => try self.binaryOperation(.OP_LESS_EQUAL),
            .OP_LOOP => {
                const offset = self.readShort();
                self.currentFrame().instruction_index -= offset;
            },
            .OP_MULTIPLY => try self.binaryOperation(.OP_MULTIPLY),
            .OP_NEGATE => try self.value_stack.push(Value{ .VAL_NUMBER = -self.value_stack.pop().VAL_NUMBER }),
            .OP_NOT => try self.value_stack.push(Value{ .VAL_BOOL = self.value_stack.pop().isFalsey() }),
            .OP_NOT_EQUAL => try self.binaryOperation(.OP_NOT_EQUAL),
            .OP_NULL => try self.value_stack.push(Value{ .VAL_NULL = undefined }),
            .OP_RETURN => {
                const result = self.value_stack.pop();
                if (self.frame_count == 1) {
                    _ = self.value_stack.pop();
                    self.call_frames[0].instruction_index += 1;
                    return;
                }
                self.frame_count -= 1;
                self.value_stack.stack_top = self.currentFrame().slots;
                try self.value_stack.push(result);
            },
            .OP_POP => _ = self.value_stack.pop(),
            .OP_PRINT => {
                try self.value_stack.pop().print(self.writer);
                try self.writer.print("\n", .{});
            },
            .OP_SET_GLOBAL => {
                self.currentFrame().instruction_index += 1;
                try self.setGlobal(self.currentChunk().values.items[self.currentChunk().byte_code.items[self.currentFrame().instruction_index]].VAL_OBJECT.as(ObjectString));
            },
            .OP_SET_GLOBAL_LONG => {
                const name_index = self.readShortWord();
                try self.setGlobal(self.currentChunk().values.items[name_index].VAL_OBJECT.as(ObjectString));
            },
            .OP_SET_LOCAL => {
                self.currentFrame().instruction_index += 1;
                const slot = @intCast(u8, self.currentChunk().byte_code.items[self.currentFrame().instruction_index]);
                self.value_stack.items[slot] = self.value_stack.peek(0);
            },
            .OP_SUBTRACT => try self.binaryOperation(.OP_SUBTRACT),
            .OP_TRUE => try self.value_stack.push(Value{ .VAL_BOOL = true }),
        }
    }
}

fn traceExecution(self: *VirtualMachine) !void {
    var index_copy = self.currentFrame().instruction_index;
    Disassembler.disassembleInstruction(self.currentChunk(), &index_copy);
    try self.writer.print("stack: ", .{});
    var counter: usize = 0;
    while (counter < 5) : (counter += 1) {
        try self.writer.print("[", .{});
        try self.value_stack.stack_top[counter].print(self.writer);
        try self.writer.print("]", .{});
    }
    try std.io.getStdOut().writer().print("\n", .{});
}

/// Reads a short from the chunk's byte code.
inline fn readShort(self: *VirtualMachine) u16 {
    var short = @intCast(u16, self.currentChunk().byte_code.items[self.currentFrame().instruction_index + 1]) << 8;
    short |= @intCast(u16, self.currentChunk().byte_code.items[self.currentFrame().instruction_index + 2]);
    self.currentFrame().instruction_index += 2;
    return short;
}

/// Reads a short from the chunk's byte code.
/// A short word is 3 bytes long.
inline fn readShortWord(self: *VirtualMachine) u24 {
    var short_word = @intCast(u24, self.currentChunk().byte_code.items[self.currentFrame().instruction_index + 1]) << 16;
    short_word |= @intCast(u24, self.currentChunk().byte_code.items[self.currentFrame().instruction_index + 2]) << 8;
    short_word |= @intCast(u24, self.currentChunk().byte_code.items[self.currentFrame().instruction_index + 3]);
    self.currentFrame().instruction_index += 3;
    return short_word;
}

/// Defines a global variable.
inline fn defineGlobal(self: *VirtualMachine, name: *ObjectString) !void {
    _ = try self.memory_mutator.globals.set(name, self.value_stack.peek(0));
    _ = self.value_stack.pop();
}

/// Gets a global variable.
inline fn getGlobal(self: *VirtualMachine, name: *ObjectString) !void {
    var value = self.memory_mutator.globals.get(name);
    if (value) |val| {
        try self.value_stack.push(val);
    } else {
        return self.reportRunTimeError("Undefined variable '{s}'", .{name.chars});
    }
}

/// Sets a global variable.
inline fn setGlobal(self: *VirtualMachine, name: *ObjectString) !void {
    var value = self.value_stack.peek(0);
    if (try self.memory_mutator.globals.set(name, value)) {
        _ = self.memory_mutator.globals.delete(name);
        return self.reportRunTimeError("Undefined variable '{s}'", .{name.chars});
    }
}

inline fn currentChunk(self: *VirtualMachine) *Chunk {
    return &self.currentFrame().function.chunk;
}

inline fn currentFrame(self: *VirtualMachine) *CallFrame {
    return &self.call_frames[self.frame_count - 1];
}

fn reportRunTimeError(self: *VirtualMachine, comptime format: []const u8, args: anytype) !void {
    std.debug.print("Runtime error:\n", .{});
    std.debug.print(format, args);
    std.debug.print("\ncaused at line {d}\n", .{self.currentChunk().lines.items[self.currentFrame().instruction_index]});
    var counter = self.frame_count - 1;
    while (counter > 0) {
        var frame = &self.call_frames[counter];
        std.debug.print("called from line {d}", .{frame.function.chunk.lines.items[frame.instruction_index]});
        if (counter != 1) {
            std.debug.print(" in function '{s}'\n", .{frame.function.name});
        } else {
            std.debug.print(" in function 'main'\n", .{});
        }
        counter -= 1;
    }
    return error.RuntimeError;
}

fn callValue(self: *VirtualMachine, callee: Value, arg_count: u8) !bool {
    switch (callee) {
        .VAL_OBJECT => {
            switch (callee.VAL_OBJECT.object_type) {
                .OBJ_FUNCTION => return self.call(callee.VAL_OBJECT.as(ObjectFunction), arg_count),
                else => {},
            }
        },
        else => {},
    }
    try self.reportRunTimeError("Can only call functions and classes", .{});
    return false;
}

fn call(self: *VirtualMachine, function: *ObjectFunction, arg_count: u8) !bool {
    if (arg_count != function.arity) {
        try self.reportRunTimeError("Expected {d} arguments but got {d}", .{ function.arity, arg_count });
    }
    if (self.frame_count == 255) {
        try self.reportRunTimeError("Stack overflow", .{});
    }
    self.call_frames[self.frame_count] = CallFrame.init(function, self.value_stack.stack_top - arg_count - 1, 0);
    self.frame_count += 1;
    return true;
}

test "Can fill stack" {
    const writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();
    var memory_mutator = MemoryMutator.init(allocator);
    var vm = try VirtualMachine.init(&writer, &memory_mutator);
    defer vm.deinit();
    var counter: usize = 0;
    while (counter < STACK_MAX) : (counter += 1) {
        try vm.value_stack.push(Value{ .VAL_BOOL = true });
    }
}
