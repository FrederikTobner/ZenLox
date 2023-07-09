const std = @import("std");

const VirtualMachine = @import("../virtual_machine.zig");
const FNV1a = @import("../fnv1a.zig");
const Value = @import("../value.zig").Value;
const MemoryMutator = @import("../memory_mutator.zig");

fn variableBasedTest(comptime code: []const u8, expectedValue: Value) !void {
    var writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();
    var memory_mutator = MemoryMutator.init(allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    try virtual_machine.interpret(code ++ " ");
    defer virtual_machine.deinit();
    try std.testing.expect(1 <= virtual_machine.memory_mutator.globals.count);
    var value = virtual_machine.memory_mutator.globals.getWithChars("i", FNV1a.hash("i"));
    try std.testing.expect(value != null);
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Addition" {
    try variableBasedTest("var i = 3 + 2;", Value{ .VAL_NUMBER = 5 });
}

test "Subtraction" {
    try variableBasedTest("var i = 3 - 2;", Value{ .VAL_NUMBER = 1 });
}

test "Multiplication" {
    try variableBasedTest("var i = 3 * 2;", Value{ .VAL_NUMBER = 6 });
}

test "Division" {
    try variableBasedTest("var i = 3 / 2;", Value{ .VAL_NUMBER = 1.5 });
}

test "Greater" {
    try variableBasedTest("var i = 3 > 2;", Value{ .VAL_BOOL = true });
}

test "Greater Equal" {
    try variableBasedTest("var i = 3 >= 2;", Value{ .VAL_BOOL = true });
}

test "Less" {
    try variableBasedTest("var i = 3 < 2;", Value{ .VAL_BOOL = false });
}

test "Less Equal" {
    try variableBasedTest("var i = 3 <= 2;", Value{ .VAL_BOOL = false });
}

test "Can define global" {
    try variableBasedTest("var i = 5;", Value{ .VAL_NUMBER = 5 });
}

test "if statement" {
    try variableBasedTest("var i = 0; if (true) i = 1;", Value{ .VAL_NUMBER = 1 });
}

test "if else" {
    try variableBasedTest("var i = 0; if (false) i = 1; else i = 2;", Value{ .VAL_NUMBER = 2 });
}

test "else if" {
    try variableBasedTest("var i = 0; if (false) i = 1; else if (true) i = 2; else i = 3;", Value{ .VAL_NUMBER = 2 });
}

test "while" {
    try variableBasedTest("var i = 0; while(i < 3) {i = i + 1;} ", Value{ .VAL_NUMBER = 3 });
}

test "for" {
    try variableBasedTest("var i = 0; for(var counter = 0; counter < 3; counter = counter + 1) {i = counter;} ", Value{ .VAL_NUMBER = 2 });
}

test "fun" {
    try variableBasedTest("fun add(a, b) { return a + b; } var i = add(1, 2);", Value{ .VAL_NUMBER = 3 });
}
