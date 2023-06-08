const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const VirtualMachine = @import("virtual_machine.zig").VirtualMachine;
const InterpreterResult = @import("virtual_machine.zig").InterpreterResult;

pub fn main() !void {
    var buffered_writer = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = buffered_writer.writer();
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = generalPurposeAllocator.allocator();
    defer _ = generalPurposeAllocator.deinit();
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();
    var vm = VirtualMachine.init();
    defer vm.deinit();
    vm.traceExecution = true;
    try chunk.addConstant(Value.fromNumber(1.2));
    try chunk.addConstant(Value.fromNumber(4.3));
    try chunk.writeOpCode(OpCode.OP_CONSTANT, 1);
    try chunk.writeByte(0, 1);
    try chunk.writeOpCode(OpCode.OP_CONSTANT, 1);
    try chunk.writeByte(1, 1);
    try chunk.writeOpCode(OpCode.OP_ADD, 1);
    try chunk.writeOpCode(OpCode.OP_RETURN, 1);
    _ = try vm.interpret(&chunk, stdout);
    try buffered_writer.flush();
}

test "simple test" {
    try std.testing.expectEqual(1, 1);
}
