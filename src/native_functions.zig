const std = @import("std");
const Value = @import("value.zig").Value;

/// Used to calculate the time since the start of the program.
pub var start_time: i64 = 0;

/// Returns the time since the start of the program in seconds with a precision of 1ms.
pub fn clock(args: []Value) Value {
    _ = args;
    return Value{ .VAL_NUMBER = @intToFloat(f64, std.time.milliTimestamp() - start_time) / std.time.ms_per_s };
}
