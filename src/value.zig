const std = @import("std");

const Object = @import("object.zig").Object;

/// The different types that a value can be
pub const Type = enum { VAL_NULL, VAL_BOOL, VAL_NUMBER, VAL_OBJECT };

/// Tagged union that can hold any of the supported types.
pub const Value = union(Type) {
    VAL_NULL: void,
    VAL_BOOL: bool,
    VAL_NUMBER: f64,
    VAL_OBJECT: *Object,

    /// Returns true if the value is null and false otherwise
    pub fn isNull(self: Value) bool {
        return switch (self) {
            .VAL_NULL => true,
            else => false,
        };
    }
    /// Returns true if the value is a boolean and false otherwise
    pub fn isBool(self: Value) bool {
        return switch (self) {
            .VAL_BOOL => true,
            else => false,
        };
    }
    /// Returns true if the value is a number and false otherwise
    pub fn isNumber(self: Value) bool {
        return switch (self) {
            .VAL_NUMBER => true,
            else => false,
        };
    }
    /// Returns true if the value is an object and false otherwise
    pub fn isObject(self: Value) bool {
        return switch (self) {
            .VAL_OBJECT => true,
            else => false,
        };
    }

    /// Returns true if the value is falsey and false otherwise
    pub fn isFalsey(self: Value) bool {
        return switch (self) {
            .VAL_NULL => true,
            .VAL_BOOL => !self.VAL_BOOL,
            .VAL_NUMBER => false,
            .VAL_OBJECT => false,
        };
    }

    /// Returns true if the values are equal and false otherwise
    pub fn isEqual(self: Value, other: Value) bool {
        switch (self) {
            .VAL_NULL => return other.isNull(),
            .VAL_BOOL => return other.isBool() and self.VAL_BOOL == other.VAL_BOOL,
            .VAL_NUMBER => return other.isNumber() and self.VAL_NUMBER == other.VAL_NUMBER,
            .VAL_OBJECT => return other.isObject() and self.VAL_OBJECT.isEqual(other.VAL_OBJECT),
        }
    }

    /// Prints the value using the given writer
    pub fn print(self: Value, writer: *const std.fs.File.Writer) !void {
        switch (self) {
            .VAL_NULL => try writer.print("null", .{}),
            .VAL_BOOL => try writer.print("{}", .{self.VAL_BOOL}),
            .VAL_NUMBER => try writer.print("{d}", .{self.VAL_NUMBER}),
            .VAL_OBJECT => try self.VAL_OBJECT.print(writer),
        }
    }

    /// Prints the value to stderr- used only for debugging purposes
    pub fn printDebug(self: Value) void {
        switch (self) {
            .VAL_NULL => std.debug.print("null", .{}),
            .VAL_BOOL => std.debug.print("{}", .{self.VAL_BOOL}),
            .VAL_NUMBER => std.debug.print("{d}", .{self.VAL_NUMBER}),
            .VAL_OBJECT => self.VAL_OBJECT.printDebug(),
        }
    }

    /// Returns a string representation of the value's type
    pub fn getPrintableType(self: Value) []const u8 {
        switch (self) {
            .VAL_NULL => return "undefiened",
            .VAL_BOOL => return "boolean",
            .VAL_NUMBER => return "number",
            .VAL_OBJECT => return "object",
        }
    }
};
