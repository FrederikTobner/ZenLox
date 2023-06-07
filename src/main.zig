const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    _ = stdout;
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = generalPurposeAllocator.allocator();
    defer {
        _ = generalPurposeAllocator.deinit();
    }
    var chunk = Chunk.init(allocator);
    try chunk.writeOpCode(OpCode.OP_RETURN, 1);
    chunk.disassembleChunk();
    chunk.deinit();
}

test "simple test" {
    try std.testing.expectEqual(1, 1);
}
