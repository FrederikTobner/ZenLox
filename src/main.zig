const std = @import("std");
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const VirtualMachine = @import("virtual_machine.zig").VirtualMachine;
const InterpretResult = @import("virtual_machine.zig").InterpretResult;
const Compiler = @import("compiler.zig").Compiler;

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
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len == 1) {
        try repl(allocator, &vm);
    } else if (args.len == 2) {
        try runFile(args[1], allocator, &vm, stdout);
    }
    try buffered_writer.flush();
}

test "simple test" {
    try std.testing.expectEqual(1, 1);
}

fn repl(allocator: std.mem.Allocator, vm: *VirtualMachine) !void {
    _ = vm;
    var buffered_writer = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = buffered_writer.writer();
    const stdin = std.io.getStdIn();
    while (true) {
        try stdout.print(">> ", .{});
        try buffered_writer.flush();
        const input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
        defer allocator.free(input);
        // No input, exit
        if (input.len == 1) {
            break;
        }
        try Compiler.compile(input, stdout);
        try buffered_writer.flush();
    }
}

fn runFile(path: []u8, allocator: std.mem.Allocator, vm: *VirtualMachine, stdout: anytype) !void {
    var fileContent = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
    _ = try vm.interpret(fileContent, stdout);
    defer allocator.free(fileContent);
}
