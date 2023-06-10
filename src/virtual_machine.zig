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
    fn push(self: *ValueStack, value: Value) void {
        if (self.stack_top_index >= STACK_MAX) {
            // Maybe return an error here instead of panicking?
            std.debug.panic("Stack overflow.", .{});
        }
        self.stack[self.stack_top_index] = value;
        self.stack_top_index += 1;
    }

    // Pops a value off the stack.
    fn pop(self: *ValueStack) Value {
        self.stack_top_index -= 1;
        return self.stack[self.stack_top_index];
    }
};

const VirtualMachine = @This();
chunk: *Chunk = undefined,
instruction_index: u32 = 0,
trace_execution: bool = @import("debug_options").traceExecution,
values: ValueStack = undefined,
writer: *const std.fs.File.Writer,
pub fn init(writer: *const std.fs.File.Writer) VirtualMachine {
    var value_stack = ValueStack{};
    value_stack.resetStack();
    return VirtualMachine{
        .values = value_stack,
        .writer = writer,
    };
}
pub fn deinit(self: *VirtualMachine) void {
    _ = self;
}
pub fn interpret(self: *VirtualMachine, allocator: std.mem.Allocator, source: []u8) !InterpretResult {
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();
    var compiler = Compiler.init();
    if (try compiler.compile(source, &chunk)) {
        self.chunk = &chunk;
        self.instruction_index = 0;
        return try self.run();
    } else {
        return InterpretResult.COMPILE_ERROR;
    }
}

fn binaryOperation(self: *VirtualMachine, op: OpCode) void {
    var b: Value = self.values.pop();
    var a: Value = self.values.pop();
    if (a.isNumber() and b.isNumber()) {
        switch (op) {
            .OP_ADD => self.values.push(Value{ .VAL_NUMBER = a.VAL_NUMBER + b.VAL_NUMBER }),
            .OP_SUBTRACT => self.values.push(Value{ .VAL_NUMBER = a.VAL_NUMBER - b.VAL_NUMBER }),
            .OP_MULTIPLY => self.values.push(Value{ .VAL_NUMBER = a.VAL_NUMBER * b.VAL_NUMBER }),
            .OP_DIVIDE => self.values.push(Value{ .VAL_NUMBER = a.VAL_NUMBER / b.VAL_NUMBER }),
            .OP_GREATER => self.values.push(Value{ .VAL_BOOL = a.VAL_NUMBER > b.VAL_NUMBER }),
            .OP_LESS => self.values.push(Value{ .VAL_BOOL = a.VAL_NUMBER < b.VAL_NUMBER }),
            .OP_GREATER_EQUAL => self.values.push(Value{ .VAL_BOOL = a.VAL_NUMBER >= b.VAL_NUMBER }),
            .OP_LESS_EQUAL => self.values.push(Value{ .VAL_BOOL = a.VAL_NUMBER <= b.VAL_NUMBER }),
            else => unreachable,
        }
    } else {
        std.debug.panic("Operands must be two numbers.", .{});
    }
}
fn run(self: *VirtualMachine) !InterpretResult {
    while (self.instruction_index < self.chunk.byte_code.items.len) : (self.instruction_index += 1) {
        if (self.trace_execution) {
            var index_copy = self.instruction_index;
            self.chunk.disassembleInstruction(&index_copy);
            try self.writer.print("stack: ", .{});
            for (self.values.stack) |value| {
                try self.writer.print("[", .{});
                try value.print(self.writer);
                try self.writer.print("]", .{});
            }
            try std.io.getStdOut().writer().print("\n", .{});
        }
        switch (@intToEnum(OpCode, self.chunk.byte_code.items[self.instruction_index])) {
            .OP_CONSTANT => {
                self.instruction_index += 1;
                self.values.push(self.chunk.values.items[self.chunk.byte_code.items[self.instruction_index]]);
            },
            .OP_CONSTANT_LONG => {
                var constant_index: u24 = @intCast(u24, self.chunk.byte_code.items[self.instruction_index + 1]) << 16;
                constant_index |= @intCast(u24, self.chunk.byte_code.items[self.instruction_index + 2]) << 8;
                constant_index |= @intCast(u24, self.chunk.byte_code.items[self.instruction_index + 3]);
                self.instruction_index += 3;
                self.values.push(self.chunk.values.items[constant_index]);
            },
            .OP_RETURN => {
                try self.values.pop().print(self.writer);
                try self.writer.print("\n", .{});
                return InterpretResult.OK;
            },
            .OP_NEGATE => self.values.push(Value{ .VAL_NUMBER = -self.values.pop().VAL_NUMBER }),
            .OP_ADD => self.binaryOperation(.OP_ADD),
            .OP_SUBTRACT => self.binaryOperation(.OP_SUBTRACT),
            .OP_MULTIPLY => self.binaryOperation(.OP_MULTIPLY),
            .OP_DIVIDE => self.binaryOperation(.OP_DIVIDE),
            .OP_NULL => self.values.push(Value{ .VAL_NULL = undefined }),
            .OP_TRUE => self.values.push(Value{ .VAL_BOOL = true }),
            .OP_FALSE => self.values.push(Value{ .VAL_BOOL = false }),
            .OP_NOT => self.values.push(Value{ .VAL_BOOL = self.values.pop().isFalsey() }),
            .OP_EQUAL => {
                var b: Value = self.values.pop();
                var a: Value = self.values.pop();
                self.values.push(Value{ .VAL_BOOL = a.isEqual(b) });
            },
            .OP_GREATER => self.binaryOperation(.OP_GREATER),
            .OP_LESS => self.binaryOperation(.OP_LESS),
            .OP_NOT_EQUAL => {
                var b: Value = self.values.pop();
                var a: Value = self.values.pop();
                self.values.push(Value{ .VAL_BOOL = !a.isEqual(b) });
            },
            .OP_GREATER_EQUAL => self.binaryOperation(.OP_GREATER_EQUAL),
            .OP_LESS_EQUAL => self.binaryOperation(.OP_LESS_EQUAL),
        }
    }
    return InterpretResult.OK;
}
