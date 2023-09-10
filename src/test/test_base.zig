const std = @import("std");

const VirtualMachine = @import("../virtual_machine.zig");
const InterpreterError = @import("../virtual_machine.zig").InterpreterError;
const FNV1a = @import("../fnv1a.zig");
const Value = @import("../value.zig").Value;
const MemoryMutator = @import("../memory_mutator.zig");

pub const ExpectedVariable = struct {
    const Self = @This();
    pub fn init(variableName: []const u8, value: Value) Self {
        return Self{ .name = variableName, .value = value };
    }
    name: []const u8,
    value: Value,
};

/// Tests if the given code assigns the expected value to the global variable with the identifier "i".
pub fn globalVariableBasedTest(comptime code: []const u8, expectedVariables: []const ExpectedVariable) !void {
    var writer = std.io.getStdOut().writer();
    var memory_mutator = MemoryMutator.init(std.testing.allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    defer virtual_machine.deinit();
    try virtual_machine.interpret(code);
    for (expectedVariables) |expectedVariable| {
        var value = virtual_machine.memory_mutator.globals.getWithChars(expectedVariable.name, FNV1a.hash(expectedVariable.name));
        try std.testing.expect(value != null);
        try std.testing.expectEqual(expectedVariable.value, value.?);
    }
}

/// Tests if the given code produces the expected error code.
pub fn errorProducingTest(comptime code: []const u8, comptime expected_error: InterpreterError) !void {
    var writer = std.io.getStdOut().writer();
    var memory_mutator = MemoryMutator.init(std.testing.allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    defer virtual_machine.deinit();
    try std.testing.expectError(expected_error, virtual_machine.interpret(code));
}
