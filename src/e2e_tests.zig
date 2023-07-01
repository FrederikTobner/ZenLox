const std = @import("std");

const VirtualMachine = @import("virtual_machine.zig");
const FNV1a = @import("fnv1a.zig");
const Value = @import("value.zig").Value;

fn e2e_test(source: []const u8) !VirtualMachine {
    var writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    var virtual_machine = VirtualMachine.init(&writer, allocator);
    try virtual_machine.interpret(source);
    errdefer virtual_machine.deinit();
    return virtual_machine;
}

test "Can define global" {
    var virtual_machine = try e2e_test("var i = 5; ");
    defer virtual_machine.deinit();
    try std.testing.expectEqual(virtual_machine.memory_mutator.globals.count, 1);
    const hash = FNV1a.hash("i");
    const value = virtual_machine.memory_mutator.globals.getWithChars("i", hash).?;
    const expectedValue = Value{
        .VAL_NUMBER = 5,
    };
    try std.testing.expectEqual(expectedValue, value);
}
