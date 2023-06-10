const std = @import("std");

const Object = @import("object.zig").Object;

pub const Type = enum { NULL, BOOL, NUMBER, OBJECT };

// Tagged union that can hold any of the supported types.
pub const Value = union(Type) {
    NULL: void,
    BOOL: bool,
    NUMBER: f64,
    OBJECT: *Object,

    pub fn isNumber(self: Value) bool {
        switch (self) {
            .NUMBER => true,
            else => false,
        }
    }

    // Prints the value using the given writer
    pub fn print(self: Value, writer: *const std.fs.File.Writer) !void {
        switch (self) {
            .NULL => try writer.print("null", .{}),
            .BOOL => try writer.print("{}", .{self.BOOL}),
            .NUMBER => try writer.print("{d}", .{self.NUMBER}),
            .OBJECT => try writer.print("object", .{}),
        }
    }

    // Prints the value to stderr- used only for debugging purposes
    pub fn printDebug(self: Value) void {
        switch (self) {
            .NULL => std.debug.print("null", .{}),
            .BOOL => std.debug.print("{}", .{self.BOOL}),
            .NUMBER => std.debug.print("{d}", .{self.NUMBER}),
            .OBJECT => std.debug.print("object", .{}),
        }
    }
};
