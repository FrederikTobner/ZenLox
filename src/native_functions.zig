const std = @import("std");
const builtin = @import("builtin");

const Value = @import("value.zig").Value;

/// Used to calculate the time since the start of the program.
pub var start_time: i64 = 0;

/// Returns the time since the start of the program in seconds with a precision of 1ms.
pub fn clock(args: []Value) Value {
    _ = args;
    const elapsedTime = std.time.milliTimestamp() - start_time;
    const elapsedTimeF: f64 = @floatFromInt(elapsedTime);
    return Value{ .VAL_NUMBER = (@as(f64, elapsedTimeF) / @as(f64, std.time.ms_per_s)) };
}

pub fn onWindows(args: []Value) Value {
    _ = args;
    return Value{ .VAL_BOOL = builtin.os.tag == .windows };
}

pub fn onLinux(args: []Value) Value {
    _ = args;
    return Value{ .VAL_BOOL = builtin.os.tag == .linux };
}

pub fn onMac(args: []Value) Value {
    _ = args;
    return Value{ .VAL_BOOL = builtin.os.tag == .macos };
}
