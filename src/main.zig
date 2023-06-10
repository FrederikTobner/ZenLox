const std = @import("std");
const VirtualMachine = @import("virtual_machine.zig");
const InterpretResult = @import("virtual_machine.zig").InterpretResult;

pub fn main() !void {
    const writter = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();
    var vm = VirtualMachine.init(&writter);
    defer vm.deinit();
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
        if (try vm.interpret(allocator, input) == InterpretResult.COMPILE_ERROR) {
            std.debug.print("Compile error\n", .{});
        }
    }
}

fn runFile(path: []u8, allocator: std.mem.Allocator, vm: *VirtualMachine) !void {
    var fileContent = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
    if (try vm.interpret(allocator, fileContent) == InterpretResult.COMPILE_ERROR) {
        std.debug.print("Compile error\n", .{});
    }
    defer allocator.free(fileContent);
}

fn show_usage(writter: *const std.fs.File.Writer) !void {
    try writter.print("Usage: clox [path]\n", .{});
}
