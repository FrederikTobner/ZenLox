const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const Compiler = @import("compiler.zig").Compiler;

pub const InterpretResult = enum {
    OK,
    COMPILE_ERROR,
    RUNTIME_ERROR,
};
const STACK_MAX: u9 = 256;
const ValueStack = struct {
    stack: [STACK_MAX]Value = undefined,
    stackTopIndex: u8 = 0,

    // Resets the stack to empty.
    fn resetStack(self: *ValueStack) void {
        self.stackTopIndex = 0;
        var startIndex: usize = 0;
        while (startIndex < STACK_MAX) : (startIndex += 1) {
            self.stack[startIndex] = Value{ .Null = undefined };
        }
    }
    // Pushes a value onto the stack.
    fn push(self: *ValueStack, value: Value) void {
        if (self.stackTopIndex >= STACK_MAX) {
            // Maybe return an error here instead of panicking?
            std.debug.panic("Stack overflow.", .{});
        }
        self.stack[self.stackTopIndex] = value;
        self.stackTopIndex += 1;
    }

    // Pops a value off the stack.
    fn pop(self: *ValueStack) Value {
        self.stackTopIndex -= 1;
        return self.stack[self.stackTopIndex];
    }
};

pub const VirtualMachine = struct {
    chunk: *Chunk = undefined,
    instructionIndex: u32 = 0,
    traceExecution: bool = false,
    values: ValueStack = undefined,
    pub fn init() VirtualMachine {
        var valueStack = ValueStack{};
        valueStack.resetStack();
        return VirtualMachine{
            .values = valueStack,
        };
    }
    pub fn deinit(self: *VirtualMachine) void {
        _ = self;
    }
    pub fn interpret(self: *VirtualMachine, source: []u8, stdout: anytype) !InterpretResult {
        _ = self;
        try Compiler.compile(source, stdout);
        return InterpretResult.OK;
    }

    fn binaryOperation(self: *VirtualMachine, op: OpCode) void {
        var b: Value = self.values.pop();
        var a: Value = self.values.pop();
        switch (a) {
            .Number => {
                switch (b) {
                    .Number => {
                        switch (op) {
                            .OP_ADD => self.values.push(Value.fromNumber(a.Number + b.Number)),
                            .OP_SUBTRACT => self.values.push(Value.fromNumber(a.Number - b.Number)),
                            .OP_MULTIPLY => self.values.push(Value.fromNumber(a.Number * b.Number)),
                            .OP_DIVIDE => self.values.push(Value.fromNumber(a.Number / b.Number)),
                            else => unreachable,
                        }
                    },
                    else => std.debug.panic("Operands must be two numbers.", .{}),
                }
            },
            else => std.debug.panic("Operands must be two numbers.", .{}),
        }
    }
    fn run(self: *VirtualMachine, stdout: anytype) !InterpretResult {
        while (self.instructionIndex < self.chunk.byteCode.items.len) : (self.instructionIndex += 1) {
            if (self.traceExecution) {
                var indexCopy = self.instructionIndex;
                try self.chunk.disassembleInstruction(&indexCopy, stdout);
                try stdout.print("stack: ", .{});
                for (self.values.stack) |value| {
                    try stdout.print("[", .{});
                    try value.print(stdout);
                    try stdout.print("]", .{});
                }
                try stdout.print("\n", .{});
            }
            switch (@intToEnum(OpCode, self.chunk.byteCode.items[self.instructionIndex])) {
                OpCode.OP_CONSTANT => {
                    self.instructionIndex += 1;
                    var value: Value = self.chunk.values.items[self.chunk.byteCode.items[self.instructionIndex]];
                    self.values.push(value);
                },
                OpCode.OP_CONSTANT_LONG => {
                    var constantIndex: u24 = @intCast(u24, self.chunk.byteCode.items[self.instructionIndex + 1]) << 16;
                    constantIndex |= @intCast(u24, self.chunk.byteCode.items[self.instructionIndex + 2]) << 8;
                    constantIndex |= @intCast(u24, self.chunk.byteCode.items[self.instructionIndex + 3]);
                    self.instructionIndex += 3;
                    self.values.push(self.chunk.values.items[constantIndex]);
                },
                OpCode.OP_RETURN => {
                    try self.values.pop().print(stdout);
                    try stdout.print("\n", .{});
                    return InterpretResult.OK;
                },
                OpCode.OP_NEGATE => self.values.push(Value.fromNumber(-self.values.pop().Number)),
                OpCode.OP_ADD => self.binaryOperation(OpCode.OP_ADD),
                OpCode.OP_SUBTRACT => self.binaryOperation(OpCode.OP_SUBTRACT),
                OpCode.OP_MULTIPLY => self.binaryOperation(OpCode.OP_MULTIPLY),
                OpCode.OP_DIVIDE => self.binaryOperation(OpCode.OP_DIVIDE),
            }
        }
        return InterpretResult.OK;
    }
};
