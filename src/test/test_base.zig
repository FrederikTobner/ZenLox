const std = @import("std");

const VirtualMachine = @import("../virtual_machine.zig");
const InterpreterError = @import("../virtual_machine.zig").InterpreterError;
const FNV1a = @import("../fnv1a.zig");
const Value = @import("../value.zig").Value;
const MemoryMutator = @import("../memory_mutator.zig");

/// Tests if the given code assigns the expected value to the global variable with the identifier "i".
pub fn globalVariableBasedTest(comptime code: []const u8, expectedValue: Value) !void {
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
pub fn errorProducingTest(comptime code: []const u8, comptime expected_error: InterpreterError) !void {
    var writer = std.io.getStdOut().writer();
    var memory_mutator = MemoryMutator.init(std.testing.allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    defer virtual_machine.deinit();
    try std.testing.expectError(expected_error, virtual_machine.interpret(code));
}
