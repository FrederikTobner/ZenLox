const std = @import("std");
const VirtualMachine = @import("virtual_machine.zig");
const InterpretResult = @import("virtual_machine.zig").InterpretResult;
const InterpreterError = @import("virtual_machine.zig").InterpreterError;
const SysExits = @import("sysexit.zig").SysExits;

pub fn main() u8 {
    const writer = std.io.getStdOut().writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();
    var vm = VirtualMachine.init(&writer, allocator);
    defer vm.deinit();
    const args = std.process.argsAlloc(allocator) catch {
        return @enumToInt(SysExits.EX_OSERR);
    };
    defer std.process.argsFree(allocator, args);
    if (switch (args.len) {
        0 => unreachable,
        1 => repl(allocator, &vm),
        2 => handleSingleArg(&writer, allocator, &vm, args[1]),
        else => show_usage(&writer),
    }) {
        return @enumToInt(SysExits.EX_OK);
    } else |err| {
        switch (err) {
            InterpreterError.COMPILE_ERROR => std.debug.print("Compile error\n", .{}),
            InterpreterError.RUNTIME_ERROR => std.debug.print("Runtime error\n", .{}),
            .AccessDenied => std.debug.print("Access denied\n", .{}),
            .BadPathName => std.debug.print("Bad path name\n", .{}),
            .BrokenPipe => std.debug.print("Broken pipe\n", .{}),
            .ConnectionResetByPeer => std.debug.print("Connection reset\n", .{}),
            .ConnectionTimedOut => std.debug.print("Connection timed out\n", .{}),
            .DeviceBusy => std.debug.print("Device busy\n", .{}),
            .DiskQuota => std.debug.print("Disk quota exceeded\n", .{}),
            .EndOfStream => std.debug.print("End of stream\n", .{}),
            .FileBusy => std.debug.print("File busy\n", .{}),
            .FileLocksNotSupported => std.debug.print("File locks not supported\n", .{}),
            .FileNotFound => std.debug.print("File not found\n", .{}),
            .FileTooBig => std.debug.print("File too big\n", .{}),
            .InputOutput => std.debug.print("Input/Output error\n", .{}),
            .InvalidHandle => std.debug.print("Invalid handle\n", .{}),
            .InvalidUtf8 => std.debug.print("Invalid UTF-8\n", .{}),
            .IsDir => std.debug.print("Is a directory\n", .{}),
            .LockViolation => std.debug.print("Lock violation\n", .{}),
            .NameTooLong => std.debug.print("Name too long\n", .{}),
            .NoDevice => std.debug.print("No device\n", .{}),
            .NoSpaceLeft => std.debug.print("No space left\n", .{}),
            .NotDir => std.debug.print("Not a directory\n", .{}),
            .NotOpenForWriting => std.debug.print("Not open for writing\n", .{}),
            .NotOpenForReading => std.debug.print("Not open for reading\n", .{}),
            .OutOfMemory => std.debug.print("Out of memory\n", .{}),
            .OperationAborted => std.debug.print("Operation aborted\n", .{}),
            .PathAlreadyExists => std.debug.print("Path already exists\n", .{}),
            .PipeBusy => std.debug.print("Pipe busy\n", .{}),
            .ProcessFdQuotaExceeded => std.debug.print("Process file descriptor quota exceeded\n", .{}),
            .SharingViolation => std.debug.print("Sharing violation\n", .{}),
            .StreamTooLong => std.debug.print("Stream too long\n", .{}),
            .SymLinkLoop => std.debug.print("Symbolic link loop\n", .{}),
            .SystemResources => std.debug.print("System resource exhausted\n", .{}),
            .SystemFdQuotaExceeded => std.debug.print("System file descriptor quota exceeded\n", .{}),
            .Unexpected => std.debug.print("Unexpected error\n", .{}),
            .Unseekable => std.debug.print("Unseekable\n", .{}),
            .WouldBlock => std.debug.print("Would block\n", .{}),
        }
        return switch (err) {
            InterpreterError.COMPILE_ERROR => @enumToInt(SysExits.EX_DATAERR),
            .AccessDenied => @enumToInt(SysExits.EX_NOPERM),
            .FileNotFound => @enumToInt(SysExits.EX_NOINPUT),
            .InvalidUtf8, .NameTooLong => @enumToInt(SysExits.EX_DATAERR),
            .NotDir => @enumToInt(SysExits.EX_NOINPUT),
            .PathAlreadyExists => @enumToInt(SysExits.EX_CANTCREAT),
            .OutOfMemory, .OperationAborted.SystemResources => @enumToInt(SysExits.EX_OSERR),
            .BadPathName, .BrokenPipe, .ConnectionResetByPeer, .ConnectionTimedOut, .DeviceBusy, .DiskQuota, .EndOfStream, .FileBusy, .FileLocksNotSupported, .FileTooBig, .InputOutput, .InvalidHandle, .IsDir, .LockViolation, .NoDevice, .NoSpaceLeft, .NotOpenForWriting, .NotOpenForReading, .PipeBusy, .ProcessFdQuotaExceeded, .SharingViolation, .StreamTooLong, .SymLinkLoop.SymLinkLoop, .SystemFdQuotaExceeded, .Unseekable, .WouldBlock => @enumToInt(SysExits.EX_IOERR),
            InterpreterError.RUNTIME_ERROR, .Unexpected => @enumToInt(SysExits.EX_SOFTWARE),
        };
    }
}

fn handleSingleArg(writer: *const std.fs.File.Writer, allocator: std.mem.Allocator, vm: *VirtualMachine, arg: []u8) !void {
    if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "--help")) {
        try show_help(writer);
    } else {
        try runFile(arg, allocator, vm);
    }
}

fn repl(allocator: std.mem.Allocator, vm: *VirtualMachine) !void {
    const stdin = std.io.getStdIn();
    while (true) {
        try std.io.getStdOut().writer().print(">> ", .{});
        const input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
        // No input
        if (input.len == 1) {
            allocator.free(input);
            break;
        }
        try run(input, vm);
        allocator.free(input);
    }
}

fn runFile(path: []u8, allocator: std.mem.Allocator, vm: *VirtualMachine) !void {
    var fileContent = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
    fileContent = try allocator.realloc(fileContent, fileContent.len + 1);
    fileContent[fileContent.len - 1] = 0;
    defer allocator.free(fileContent);
    try run(fileContent, vm);
}

fn run(code: []const u8, vm: *VirtualMachine) !void {
    try vm.interpret(code);
}

fn show_usage(writer: *const std.fs.File.Writer) !void {
    try writer.print("Usage: clox [path]\n", .{});
}

fn show_help(writer: *const std.fs.File.Writer) !void {
    try writer.print("Usage: clox [path]\n", .{});
    try writer.print("  path: Path to a file to run\n", .{});
}
