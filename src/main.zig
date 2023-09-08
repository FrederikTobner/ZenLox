const std = @import("std");
const VirtualMachine = @import("virtual_machine.zig");
const InterpretResult = @import("virtual_machine.zig").InterpretResult;
const InterpreterError = @import("virtual_machine.zig").InterpreterError;
const MemoryMutator = @import("memory_mutator.zig");
const SysExits = @import("sysexit.zig").SysExits;

/// Main entry point for the program.
pub fn main() u8 {
    const writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();
    var memory_mutator = MemoryMutator.init(allocator);
    memory_mutator.defineNativeFunctions() catch {
        return @intFromEnum(SysExits.EX_OSERR);
    };
    var vm = VirtualMachine.init(&writer, &memory_mutator) catch {
        return @intFromEnum(SysExits.EX_OSERR);
    };
    defer vm.deinit();
    const args = std.process.argsAlloc(allocator) catch {
        return @intFromEnum(SysExits.EX_OSERR);
    };
    defer std.process.argsFree(allocator, args);
    if (switch (args.len) {
        0 => unreachable,
        1 => repl(allocator, &vm),
        2 => handleSingleArg(&writer, allocator, &vm, args[1]),
        else => show_usage(&writer),
    }) {
        return @intFromEnum(SysExits.EX_OK);
    } else |err| {
        switch (err) {
            error.CompileError => std.debug.print("Compile error\n", .{}),
            error.RuntimeError => std.debug.print("Runtime error\n", .{}),
            error.AccessDenied => std.debug.print("Access denied\n", .{}),
            error.BadPathName => std.debug.print("Bad path name\n", .{}),
            error.BrokenPipe => std.debug.print("Broken pipe\n", .{}),
            error.ConnectionResetByPeer => std.debug.print("Connection reset\n", .{}),
            error.ConnectionTimedOut => std.debug.print("Connection timed out\n", .{}),
            error.DeviceBusy => std.debug.print("Device busy\n", .{}),
            error.DiskQuota => std.debug.print("Disk quota exceeded\n", .{}),
            error.EndOfStream => std.debug.print("End of stream\n", .{}),
            error.FileBusy => std.debug.print("File busy\n", .{}),
            error.FileLocksNotSupported => std.debug.print("File locks not supported\n", .{}),
            error.FileNotFound => std.debug.print("File not found\n", .{}),
            error.FileTooBig => std.debug.print("File too big\n", .{}),
            error.InputOutput => std.debug.print("Input/Output error\n", .{}),
            error.InvalidHandle => std.debug.print("Invalid handle\n", .{}),
            error.InvalidArgument => std.debug.print("Invalid argument\n", .{}),
            error.InvalidUtf8 => std.debug.print("Invalid UTF-8\n", .{}),
            error.IsDir => std.debug.print("Is a directory\n", .{}),
            error.LockViolation => std.debug.print("Lock violation\n", .{}),
            error.NameTooLong => std.debug.print("Name too long\n", .{}),
            error.NetNameDeleted => std.debug.print("Network name deleted\n", .{}),
            error.NetworkNotFound => std.debug.print("Network not found\n", .{}),
            error.NoDevice => std.debug.print("No device\n", .{}),
            error.NoSpaceLeft => std.debug.print("No space left\n", .{}),
            error.NotDir => std.debug.print("Not a directory\n", .{}),
            error.NotOpenForWriting => std.debug.print("Not open for writing\n", .{}),
            error.NotOpenForReading => std.debug.print("Not open for reading\n", .{}),
            error.OutOfMemory => std.debug.print("Out of memory\n", .{}),
            error.OperationAborted => std.debug.print("Operation aborted\n", .{}),
            error.PathAlreadyExists => std.debug.print("Path already exists\n", .{}),
            error.PipeBusy => std.debug.print("Pipe busy\n", .{}),
            error.ProcessFdQuotaExceeded => std.debug.print("Process file descriptor quota exceeded\n", .{}),
            error.SharingViolation => std.debug.print("Sharing violation\n", .{}),
            error.StreamTooLong => std.debug.print("Stream too long\n", .{}),
            error.SymLinkLoop => std.debug.print("Symbolic link loop\n", .{}),
            error.SystemResources => std.debug.print("System resource exhausted\n", .{}),
            error.SystemFdQuotaExceeded => std.debug.print("System file descriptor quota exceeded\n", .{}),
            error.Unexpected => std.debug.print("Unexpected error\n", .{}),
            error.Unseekable => std.debug.print("Unseekable\n", .{}),
            error.WouldBlock => std.debug.print("Would block\n", .{}),
        }
        return switch (err) {
            error.CompileError => @intFromEnum(SysExits.EX_DATAERR),
            error.AccessDenied => @intFromEnum(SysExits.EX_NOPERM),
            error.FileNotFound => @intFromEnum(SysExits.EX_NOINPUT),
            error.NotDir => @intFromEnum(SysExits.EX_NOINPUT),
            error.PathAlreadyExists => @intFromEnum(SysExits.EX_CANTCREAT),
            error.RuntimeError, error.InvalidArgument, error.Unexpected => @intFromEnum(SysExits.EX_SOFTWARE),
            error.InvalidUtf8, error.NameTooLong => @intFromEnum(SysExits.EX_DATAERR),
            error.OutOfMemory, error.OperationAborted, error.SystemResources => @intFromEnum(SysExits.EX_OSERR),
            error.BadPathName, error.BrokenPipe, error.ConnectionResetByPeer, error.ConnectionTimedOut, error.DeviceBusy, error.DiskQuota, error.EndOfStream, error.FileBusy, error.FileLocksNotSupported, error.FileTooBig, error.InputOutput, error.InvalidHandle, error.IsDir, error.LockViolation, error.NetNameDeleted, error.NetworkNotFound, error.NoDevice, error.NoSpaceLeft, error.NotOpenForWriting, error.NotOpenForReading, error.PipeBusy, error.ProcessFdQuotaExceeded, error.SharingViolation, error.StreamTooLong, error.SymLinkLoop, error.SystemFdQuotaExceeded, error.Unseekable, error.WouldBlock => @intFromEnum(SysExits.EX_IOERR),
        };
    }
}

/// Handles a single argument passed to the program.
fn handleSingleArg(writer: *const std.fs.File.Writer, allocator: std.mem.Allocator, vm: *VirtualMachine, arg: []u8) !void {
    if ((arg.len == 6 and std.mem.eql(u8, arg, "--help")) or (arg.len == 2 and std.mem.eql(u8, arg, "-h"))) {
        try show_help(writer);
    } else if (std.mem.eql(u8, arg[arg.len - 3 .. arg.len], ".zl")) {
        try runFile(arg, allocator, vm);
    } else {
        try show_usage(writer);
    }
}

/// Starts a REPL session.
fn repl(allocator: std.mem.Allocator, vm: *VirtualMachine) !void {
    const stdin = std.io.getStdIn();
    try std.io.getStdOut().writer().print(">> ", .{});
    var input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
    errdefer allocator.free(input);
    while (true) {
        // No input
        if (input.len == 0) {
            allocator.free(input);
            break;
        }
        try run(input, vm);
        allocator.free(input);
        try std.io.getStdOut().writer().print(">> ", .{});
        input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
    }
}

/// Runs the program from a file.
fn runFile(path: []u8, allocator: std.mem.Allocator, vm: *VirtualMachine) !void {
    var fileContent = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
    defer allocator.free(fileContent);
    try run(fileContent, vm);
}

/// Runs the program from a string.
fn run(code: []const u8, vm: *VirtualMachine) !void {
    try vm.interpret(code);
}

/// Shows the usage of the program.
fn show_usage(writer: *const std.fs.File.Writer) !void {
    try writer.print("Usage: Zenlox [path]\n", .{});
}

/// Shows the help of ZenLox.
fn show_help(writer: *const std.fs.File.Writer) !void {
    try writer.print("Usage: Zenlox [path]\n", .{});
    try writer.print("  path: Path to a file to run\n", .{});
}
