const std = @import("std");
const Chunk = @import("chunk.zig");
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const Compiler = @import("compiler.zig");

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

const VirtualMachine = @This();
chunk: *Chunk = undefined,
instructionIndex: u32 = 0,
traceExecution: bool = false,
values: ValueStack = undefined,
writer: *const std.fs.File.Writer,
pub fn init(writer: *const std.fs.File.Writer) VirtualMachine {
    var valueStack = ValueStack{};
    valueStack.resetStack();
    return VirtualMachine{
        .values = valueStack,
        .writer = writer,
    };
}
pub fn deinit(self: *VirtualMachine) void {
    _ = self;
}
pub fn interpret(self: *VirtualMachine, allocator: std.mem.Allocator, source: []u8) !InterpretResult {
    var chunk = Chunk.init(allocator);
    var compiler = Compiler.init();
    if (try compiler.compile(source, &chunk)) {
        return InterpretResult.COMPILE_ERROR;
    } else {
        self.chunk = &chunk;
        self.instructionIndex = 0;
        return try self.run();
    }
}

fn binaryOperation(self: *VirtualMachine, op: OpCode) void {
    var b: Value = self.values.pop();
    var a: Value = self.values.pop();
    switch (a) {
        .Number => {
            switch (b) {
                .Number => {
                    switch (op) {
                        .OP_ADD => self.values.push(Value{ .Number = a.Number + b.Number }),
                        .OP_SUBTRACT => self.values.push(Value{ .Number = a.Number - b.Number }),
                        .OP_MULTIPLY => self.values.push(Value{ .Number = a.Number * b.Number }),
                        .OP_DIVIDE => self.values.push(Value{ .Number = a.Number / b.Number }),
                        else => unreachable,
                    }
                },
                else => std.debug.panic("Operands must be two numbers.", .{}),
            }
        },
        else => std.debug.panic("Operands must be two numbers.", .{}),
    }
}
fn run(self: *VirtualMachine) !InterpretResult {
    while (self.instructionIndex < self.chunk.byte_code.items.len) : (self.instructionIndex += 1) {
        if (self.traceExecution) {
            var indexCopy = self.instructionIndex;
            self.chunk.disassembleInstruction(&indexCopy);
            try self.writer.print("stack: ", .{});
            for (self.values.stack) |value| {
                try self.writer.print("[", .{});
                try value.print(self.writer);
                try self.writer.print("]", .{});
            }
            try std.io.getStdOut().writer().print("\n", .{});
        }
        switch (@intToEnum(OpCode, self.chunk.byte_code.items[self.instructionIndex])) {
            OpCode.OP_CONSTANT => {
                self.instructionIndex += 1;
                var value: Value = self.chunk.values.items[self.chunk.byte_code.items[self.instructionIndex]];
                self.values.push(value);
            },
            OpCode.OP_CONSTANT_LONG => {
                var constantIndex: u24 = @intCast(u24, self.chunk.byte_code.items[self.instructionIndex + 1]) << 16;
                constantIndex |= @intCast(u24, self.chunk.byte_code.items[self.instructionIndex + 2]) << 8;
                constantIndex |= @intCast(u24, self.chunk.byte_code.items[self.instructionIndex + 3]);
                self.instructionIndex += 3;
                self.values.push(self.chunk.values.items[constantIndex]);
            },
            OpCode.OP_RETURN => {
                try self.values.pop().print(self.writer);
                try self.writer.print("\n", .{});
                return InterpretResult.OK;
            },
            OpCode.OP_NEGATE => self.values.push(Value{ .Number = -self.values.pop().Number }),
            OpCode.OP_ADD => self.binaryOperation(OpCode.OP_ADD),
            OpCode.OP_SUBTRACT => self.binaryOperation(OpCode.OP_SUBTRACT),
            OpCode.OP_MULTIPLY => self.binaryOperation(OpCode.OP_MULTIPLY),
            OpCode.OP_DIVIDE => self.binaryOperation(OpCode.OP_DIVIDE),
        }
    }
    return InterpretResult.OK;
}
