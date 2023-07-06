const std = @import("std");
const Value = @import("value.zig").Value;

pub fn clock(args: []Value) Value {
    _ = args;
    return Value{ .VAL_NUMBER = @intToFloat(f64, std.time.timestamp()) };
}
