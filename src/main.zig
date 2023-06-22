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
            InterpreterError.COMPILE_ERROR => {
                std.debug.print("Compile error\n", .{});
                return @enumToInt(SysExits.EX_DATAERR);
            },
            InterpreterError.RUNTIME_ERROR => {
                std.debug.print("Runtime error\n", .{});
                return @enumToInt(SysExits.EX_SOFTWARE);
            },
            error.AccessDenied => {
                std.debug.print("Access denied\n", .{});
                return @enumToInt(SysExits.EX_NOPERM);
            },
            error.BadPathName => {
                std.debug.print("Bad path name\n", .{});
                return @enumToInt(SysExits.EX_NOINPUT);
            },
            error.BrokenPipe => {
                std.debug.print("Broken pipe\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.ConnectionResetByPeer => {
                std.debug.print("Connection reset\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.ConnectionTimedOut => {
                std.debug.print("Connection timed out\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.DeviceBusy => {
                std.debug.print("Device busy\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.DiskQuota => {
                std.debug.print("Disk quota exceeded\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.EndOfStream => {
                std.debug.print("End of stream\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.FileBusy => {
                std.debug.print("File busy\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.FileLocksNotSupported => {
                std.debug.print("File locks not supported\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.FileNotFound => {
                std.debug.print("File not found\n", .{});
                return @enumToInt(SysExits.EX_NOINPUT);
            },
            error.FileTooBig => {
                std.debug.print("File too big\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.InputOutput => {
                std.debug.print("Input/Output error\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.InvalidHandle => {
                std.debug.print("Invalid handle\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.InvalidUtf8 => {
                std.debug.print("Invalid UTF-8\n", .{});
                return @enumToInt(SysExits.EX_DATAERR);
            },
            error.IsDir => {
                std.debug.print("Is a directory\n", .{});
                return @enumToInt(SysExits.EX_NOINPUT);
            },
            error.LockViolation => {
                std.debug.print("Lock violation\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.NameTooLong => {
                std.debug.print("Name too long\n", .{});
                return @enumToInt(SysExits.EX_DATAERR);
            },
            error.NoDevice => {
                std.debug.print("No device\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.NoSpaceLeft => {
                std.debug.print("No space left\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.NotDir => {
                std.debug.print("Not a directory\n", .{});
                return @enumToInt(SysExits.EX_NOINPUT);
            },
            error.NotOpenForWriting => {
                std.debug.print("Not open for writing\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.NotOpenForReading => {
                std.debug.print("Not open for reading\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.OutOfMemory => {
                std.debug.print("Out of memory\n", .{});
                return @enumToInt(SysExits.EX_OSERR);
            },
            error.OperationAborted => {
                std.debug.print("Operation aborted\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.PathAlreadyExists => {
                std.debug.print("Path already exists\n", .{});
                return @enumToInt(SysExits.EX_CANTCREAT);
            },
            error.PipeBusy => {
                std.debug.print("Pipe busy\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.ProcessFdQuotaExceeded => {
                std.debug.print("Process file descriptor quota exceeded\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.SharingViolation => {
                std.debug.print("Sharing violation\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.StreamTooLong => {
                std.debug.print("Stream too long\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.SymLinkLoop => {
                std.debug.print("Symbolic link loop\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.SystemResources => {
                std.debug.print("System resource exhausted\n", .{});
                return @enumToInt(SysExits.EX_OSERR);
            },
            error.SystemFdQuotaExceeded => {
                std.debug.print("System file descriptor quota exceeded\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.Unexpected => {
                std.debug.print("Unexpected error\n", .{});
                return @enumToInt(SysExits.EX_SOFTWARE);
            },
            error.Unseekable => {
                std.debug.print("Unseekable\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
            error.WouldBlock => {
                std.debug.print("Would block\n", .{});
                return @enumToInt(SysExits.EX_IOERR);
            },
        }
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
