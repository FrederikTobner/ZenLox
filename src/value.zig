const std = @import("std");

const Object = @import("object.zig").Object;

pub const Type = enum { VAL_NULL, VAL_BOOL, VAL_NUMBER, VAL_OBJECT };

// Tagged union that can hold any of the supported types.
pub const Value = union(Type) {
    VAL_NULL: void,
    VAL_BOOL: bool,
    VAL_NUMBER: f64,
    VAL_OBJECT: *Object,

    pub fn isNull(self: Value) bool {
        return switch (self) {
            .VAL_NULL => true,
            else => false,
        };
    }

    pub fn isBool(self: Value) bool {
        return switch (self) {
            .VAL_BOOL => true,
            else => false,
        };
    }

    pub fn isNumber(self: Value) bool {
        return switch (self) {
            .VAL_NUMBER => true,
            else => false,
        };
    }

    pub fn isObject(self: Value) bool {
        return switch (self) {
            .VAL_OBJECT => true,
            else => false,
        };
    }

    pub fn isFalsey(self: Value) bool {
        return switch (self) {
            .VAL_NULL => true,
            .VAL_BOOL => !self.VAL_BOOL,
            .VAL_NUMBER => false,
            .VAL_OBJECT => false,
        };
    }

    pub fn isEqual(self: Value, other_value: Value) bool {
        switch (self) {
            .VAL_NULL => return other_value.isNull(),
            .VAL_BOOL => return other_value.isBool() and self.VAL_BOOL == other_value.VAL_BOOL,
            .VAL_NUMBER => return other_value.isNumber() and self.VAL_NUMBER == other_value.VAL_NUMBER,
            .VAL_OBJECT => return other_value.isObject() and self.VAL_OBJECT == other_value.VAL_OBJECT,
        }
    }

    // Prints the value using the given writer
    pub fn print(self: Value, writer: *const std.fs.File.Writer) !void {
        switch (self) {
            .VAL_NULL => try writer.print("null", .{}),
            .VAL_BOOL => try writer.print("{}", .{self.VAL_BOOL}),
            .VAL_NUMBER => try writer.print("{d}", .{self.VAL_NUMBER}),
            .VAL_OBJECT => try writer.print("object", .{}),
        }
    }

    // Prints the value to stderr- used only for debugging purposes
    pub fn printDebug(self: Value) void {
        switch (self) {
            .VAL_NULL => std.debug.print("null", .{}),
            .VAL_BOOL => std.debug.print("{}", .{self.VAL_BOOL}),
            .VAL_NUMBER => std.debug.print("{d}", .{self.VAL_NUMBER}),
            .VAL_OBJECT => std.debug.print("object", .{}),
        }
    }
};
