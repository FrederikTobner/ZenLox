const std = @import("std");

const VirtualMachine = @import("../virtual_machine.zig");
const InterpreterError = @import("../virtual_machine.zig").InterpreterError;
const FNV1a = @import("../fnv1a.zig");
const Value = @import("../value.zig").Value;
const MemoryMutator = @import("../memory_mutator.zig");

/// Tests if the given code produces the expected value.
fn globalVariableBasedTest(comptime code: []const u8, expectedValue: Value) !void {
    var writer = std.io.getStdOut().writer();
    var memory_mutator = MemoryMutator.init(std.testing.allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    defer virtual_machine.deinit();
    try virtual_machine.interpret(code);
    var value = virtual_machine.memory_mutator.globals.getWithChars("i", FNV1a.hash("i"));
    try std.testing.expect(value != null);
    try std.testing.expectEqual(expectedValue, value.?);
}

/// Tests if the given code produces the expected error.
fn errorProducingTest(comptime code: []const u8, comptime expected_error: InterpreterError) !void {
    var writer = std.io.getStdOut().writer();
    var memory_mutator = MemoryMutator.init(std.testing.allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    defer virtual_machine.deinit();
    try std.testing.expectError(expected_error, virtual_machine.interpret(code));
}

test "Addition" {
    try globalVariableBasedTest("var i = 3 + 2;", Value{ .VAL_NUMBER = 5 });
}

test "Subtraction" {
    try globalVariableBasedTest("var i = 3 - 2;", Value{ .VAL_NUMBER = 1 });
}

test "Multiplication" {
    try globalVariableBasedTest("var i = 3 * 2;", Value{ .VAL_NUMBER = 6 });
}

test "Division" {
    try globalVariableBasedTest("var i = 3 / 2;", Value{ .VAL_NUMBER = 1.5 });
}

test "Greater" {
    try globalVariableBasedTest("var i = 3 > 2;", Value{ .VAL_BOOL = true });
}

test "Greater Equal" {
    try globalVariableBasedTest("var i = 3 >= 2;", Value{ .VAL_BOOL = true });
}

test "Less" {
    try globalVariableBasedTest("var i = 3 < 2;", Value{ .VAL_BOOL = false });
}

test "Less Equal" {
    try globalVariableBasedTest("var i = 3 <= 2;", Value{ .VAL_BOOL = false });
}

test "Can define global" {
    try globalVariableBasedTest("var i = 5;", Value{ .VAL_NUMBER = 5 });
}

test "if statement" {
    try globalVariableBasedTest("var i = 0; if (true) i = 1;", Value{ .VAL_NUMBER = 1 });
}

test "if else" {
    try globalVariableBasedTest("var i = 0; if (false) i = 1; else i = 2;", Value{ .VAL_NUMBER = 2 });
}

test "else if" {
    try globalVariableBasedTest("var i = 0; if (false) i = 1; else if (true) i = 2; else i = 3;", Value{ .VAL_NUMBER = 2 });
}

test "while" {
    try globalVariableBasedTest("var i = 0; while(i < 3) {i = i + 1;} ", Value{ .VAL_NUMBER = 3 });
}

test "for" {
    try globalVariableBasedTest("var i = 0; for(var counter = 0; counter < 3; counter = counter + 1) {i = counter;} ", Value{ .VAL_NUMBER = 2 });
}

test "function" {
    try globalVariableBasedTest("fun add(a, b) { return a + b; } var i = add(1, 2);", Value{ .VAL_NUMBER = 3 });
}

test "function with global upvalue" {
    try globalVariableBasedTest("var i = 3; fun inc() {i = i + 1;} inc();", Value{ .VAL_NUMBER = 4 });
}

// Errors

test "undefined variable" {
    try errorProducingTest("i = 5;", InterpreterError.RuntimeError);
}

test "return at top level" {
    try errorProducingTest("return 1;", InterpreterError.CompileError);
}

test "violate arrity" {
    try errorProducingTest("fun add(a, b) { return a + b; } var i = add(1);", InterpreterError.RuntimeError);
}
