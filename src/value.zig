const std = @import("std");

const Object = @import("object.zig").Object;

pub const Type = enum { Null, Bool, Number, Obj };

// Tagged union that can hold any of the supported types.
pub const Value = union(Type) {
    Null: void,
    Bool: bool,
    Number: f64,
    Obj: *Object,

    // Prints the value using the given writer
    pub fn print(self: Value, writer: *const std.fs.File.Writer) !void {
        switch (self) {
            .Null => try writer.print("null", .{}),
            .Bool => try writer.print("{}", .{self.Bool}),
            .Number => try writer.print("{d}", .{self.Number}),
            .Obj => try writer.print("object", .{}),
        }
    }

    // Prints the value to stderr- used only for debugging purposes
    pub fn printDebug(self: Value) void {
        switch (self) {
            .Null => std.debug.print("null", .{}),
            .Bool => std.debug.print("{}", .{self.Bool}),
            .Number => std.debug.print("{d}", .{self.Number}),
            .Obj => std.debug.print("object", .{}),
        }
    }
};
