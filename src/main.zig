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
            error.Compile_Error => std.debug.print("Compile error\n", .{}),
            error.Runtime_Error => std.debug.print("Runtime error\n", .{}),
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
            error.InvalidUtf8 => std.debug.print("Invalid UTF-8\n", .{}),
            error.IsDir => std.debug.print("Is a directory\n", .{}),
            error.LockViolation => std.debug.print("Lock violation\n", .{}),
            error.NameTooLong => std.debug.print("Name too long\n", .{}),
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
            error.Compile_Error => @enumToInt(SysExits.EX_DATAERR),
            error.AccessDenied => @enumToInt(SysExits.EX_NOPERM),
            error.FileNotFound => @enumToInt(SysExits.EX_NOINPUT),
            error.InvalidUtf8, error.NameTooLong => @enumToInt(SysExits.EX_DATAERR),
            error.NotDir => @enumToInt(SysExits.EX_NOINPUT),
            error.PathAlreadyExists => @enumToInt(SysExits.EX_CANTCREAT),
            error.OutOfMemory, error.OperationAborted, error.SystemResources => @enumToInt(SysExits.EX_OSERR),
            error.BadPathName, error.BrokenPipe, error.ConnectionResetByPeer, error.ConnectionTimedOut, error.DeviceBusy, error.DiskQuota, error.EndOfStream, error.FileBusy, error.FileLocksNotSupported, error.FileTooBig, error.InputOutput, error.InvalidHandle, error.IsDir, error.LockViolation, error.NoDevice, error.NoSpaceLeft, error.NotOpenForWriting, error.NotOpenForReading, error.PipeBusy, error.ProcessFdQuotaExceeded, error.SharingViolation, error.StreamTooLong, error.SymLinkLoop, error.SystemFdQuotaExceeded, error.Unseekable, error.WouldBlock => @enumToInt(SysExits.EX_IOERR),
            error.Runtime_Error, error.Unexpected => @enumToInt(SysExits.EX_SOFTWARE),
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
    try std.io.getStdOut().writer().print(">> ", .{});
    var input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
    errdefer allocator.free(input);
    while (true) {
        // No input
        if (input.len == 1) {
            allocator.free(input);
            break;
        }
        try run(input, vm);
        allocator.free(input);
        try std.io.getStdOut().writer().print(">> ", .{});
        input = try stdin.reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
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
