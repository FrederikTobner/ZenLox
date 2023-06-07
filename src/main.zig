const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bufferedWriter = std.io.bufferedWriter(stdout_file);
    const stdout = bufferedWriter.writer();
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = generalPurposeAllocator.allocator();
    defer {
        _ = generalPurposeAllocator.deinit();
    }
    var chunk = Chunk.init(allocator);
    try chunk.writeOpCode(OpCode.OP_RETURN, 1);
    try chunk.writeOpCode(OpCode.OP_CONSTANT, 1);
    try chunk.writeByte(0, 1);
    try chunk.addConstant(Value.fromNumber(1.2));
    try chunk.disassembleChunk(stdout);
    chunk.deinit();
    try bufferedWriter.flush();
}

test "simple test" {
    try std.testing.expectEqual(1, 1);
}
