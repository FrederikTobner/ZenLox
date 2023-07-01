const std = @import("std");

const VirtualMachine = @import("virtual_machine.zig");
const FNV1a = @import("fnv1a.zig");
const Value = @import("value.zig").Value;

fn vmStateTest(source: []const u8) !VirtualMachine {
    var writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    var virtual_machine = VirtualMachine.init(&writer, allocator);
    try virtual_machine.interpret(source);
    errdefer virtual_machine.deinit();
    return virtual_machine;
}

test "Addition" {
    var virtual_machine = try vmStateTest("var i = 3 + 2; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_NUMBER = 5,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Subtraction" {
    var virtual_machine = try vmStateTest("var i = 3 - 2; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_NUMBER = 1,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Multiplication" {
    var virtual_machine = try vmStateTest("var i = 3 * 2; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_NUMBER = 6,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Division" {
    var virtual_machine = try vmStateTest("var i = 3 / 2; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_NUMBER = 1.5,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Greater" {
    var virtual_machine = try vmStateTest("var i = 3 > 2; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_BOOL = true,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Greater Equal" {
    var virtual_machine = try vmStateTest("var i = 3 >= 2; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_BOOL = true,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Less" {
    var virtual_machine = try vmStateTest("var i = 3 < 2; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_BOOL = false,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Less Equal" {
    var virtual_machine = try vmStateTest("var i = 3 <= 2; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_BOOL = false,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}

test "Can define global" {
    var virtual_machine = try vmStateTest("var i = 5; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash);
    try std.testing.expect(value != null);
    const expectedValue = Value{
        .VAL_NUMBER = 5,
    };
    try std.testing.expectEqual(expectedValue, value.?);
}
