const std = @import("std");

const VirtualMachine = @import("../virtual_machine.zig");
const FNV1a = @import("../fnv1a.zig");
const Value = @import("../value.zig").Value;
const MemoryMutator = @import("../memory_mutator.zig");

fn vmStateTest(source: []const u8) !VirtualMachine {
    var writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    var memory_mutator = MemoryMutator.init(allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    try virtual_machine.interpret(source);
    errdefer virtual_machine.deinit();
    return virtual_machine;
}

fn variableBasedTest(comptime assignedValue: []const u8, expectedValue: Value) !void {
    var writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();
    var memory_mutator = MemoryMutator.init(allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    try virtual_machine.interpret("var name = " ++ assignedValue ++ "; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    var value = virtual_machine.memory_mutator.globals.getWithChars("name", FNV1a.hash("name"));
    try std.testing.expect(value != null);
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Addition" {
    try variableBasedTest("3 + 2", Value{
        .VAL_NUMBER = 5,
    });
}

test "Subtraction" {
    try variableBasedTest("3 - 2", Value{
        .VAL_NUMBER = 1,
    });
}

test "Multiplication" {
    try variableBasedTest("3 * 2", Value{
        .VAL_NUMBER = 6,
    });
}

test "Division" {
    try variableBasedTest("3 / 2", Value{
        .VAL_NUMBER = 1.5,
    });
}

test "Greater" {
    try variableBasedTest("3 > 2", Value{
        .VAL_BOOL = true,
    });
}

test "Greater Equal" {
    try variableBasedTest("3 >= 2", Value{
        .VAL_BOOL = true,
    });
}

test "Less" {
    try variableBasedTest("3 < 2", Value{
        .VAL_BOOL = false,
    });
}

test "Less Equal" {
    try variableBasedTest("3 <= 2", Value{
        .VAL_BOOL = false,
    });
}

test "Can define global" {
    try variableBasedTest("5", Value{
        .VAL_NUMBER = 5,
    });
}

test "if statement" {
    var writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    var memory_mutator = MemoryMutator.init(allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    try virtual_machine.interpret("var i = 0; if (true) i = 10; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    var value = virtual_machine.memory_mutator.globals.getWithChars("i", FNV1a.hash("i"));
    try std.testing.expect(value != null);
    try std.testing.expectEqual(Value{ .VAL_NUMBER = 10 }, value.?);
}

test "if else" {
    var writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    var memory_mutator = MemoryMutator.init(allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    try virtual_machine.interpret("var i = 0; if (false) i = 10; else i = 20; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    var value = virtual_machine.memory_mutator.globals.getWithChars("i", FNV1a.hash("i"));
    try std.testing.expect(value != null);
    try std.testing.expectEqual(Value{ .VAL_NUMBER = 20 }, value.?);
}

test "else if" {
    var writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    var memory_mutator = MemoryMutator.init(allocator);
    var virtual_machine = try VirtualMachine.init(&writer, &memory_mutator);
    try virtual_machine.interpret("var i = 0; if (false) i = 10; else if (true) i = 20; else i = 30; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    var value = virtual_machine.memory_mutator.globals.getWithChars("i", FNV1a.hash("i"));
    try std.testing.expect(value != null);
    try std.testing.expectEqual(Value{ .VAL_NUMBER = 20 }, value.?);
}
