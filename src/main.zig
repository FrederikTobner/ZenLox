const std = @import("std");
const Chunk = @import("chunk.zig");
const OpCode = @import("chunk.zig").OpCode;
const Value = @import("value.zig").Value;
const VirtualMachine = @import("virtual_machine.zig");
const InterpretResult = @import("virtual_machine.zig").InterpretResult;
const Compiler = @import("compiler.zig");

pub fn main() !void {
    const writter = std.io.getStdOut().writer();
    var generalPurposeAllocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = generalPurposeAllocator.allocator();
    defer _ = generalPurposeAllocator.deinit();
    var chunk = Chunk.init(allocator);
    defer chunk.deinit();
    var vm = VirtualMachine.init(&writter);
    defer vm.deinit();
    vm.traceExecution = true;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len == 1) {
        try repl(allocator, &vm);
    } else if (args.len == 2) {
        try runFile(args[1], allocator, &vm);
    } else {
        try show_usage(&writter);
    }
}

test "simple test" {
    try std.testing.expectEqual(1, 1);
}

fn repl(allocator: std.mem.Allocator, vm: *VirtualMachine) !void {
    const stdin = std.io.getStdIn();
    while (true) {
        try std.io.getStdOut().writer().print(">> ", .{});
        const input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
        defer allocator.free(input);
        // No input
        if (input.len == 1) {
            break;
        }
        _ = try vm.interpret(allocator, input);
    }
}

fn runFile(path: []u8, allocator: std.mem.Allocator, vm: *VirtualMachine) !void {
    var fileContent = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
    _ = try vm.interpret(allocator, fileContent);
    defer allocator.free(fileContent);
}

fn show_usage(writter: *const std.fs.File.Writer) !void {
    try writter.print("Usage: clox [path]\n", .{});
}
