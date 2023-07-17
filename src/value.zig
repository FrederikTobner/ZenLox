const std = @import("std");

const Object = @import("object.zig").Object;

/// The different types that a value can be
pub const ValueType = enum { VAL_NULL, VAL_BOOL, VAL_NUMBER, VAL_OBJECT };

/// Tagged union that can hold any of the supported types.
pub const Value = union(ValueType) {
    /// The null value
    VAL_NULL: void,
    /// The boolean value
    VAL_BOOL: bool,
    /// The numerical value
    VAL_NUMBER: f64,
    /// The object value (a pointer to the object field in a function)
    VAL_OBJECT: *Object,

    /// Returns true if the value is of the given type and false otherwise
    pub fn is(self: Value, comptime value_type: ValueType) bool {
        return switch (self) {
            value_type => true,
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
            .VAL_NULL => return other.is(.VAL_NULL),
            .VAL_BOOL => return other.is(.VAL_BOOL) and self.VAL_BOOL == other.VAL_BOOL,
            .VAL_NUMBER => return other.is(.VAL_NUMBER) and self.VAL_NUMBER == other.VAL_NUMBER,
            .VAL_OBJECT => return other.is(.VAL_OBJECT) and self.VAL_OBJECT.isEqual(other.VAL_OBJECT),
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

// Tests

test "Can detetmine value type" {
    var value = Value{ .VAL_NULL = undefined };
    try std.testing.expect(value.is(.VAL_NULL));
    try std.testing.expect(!value.is(.VAL_BOOL));
    try std.testing.expect(!value.is(.VAL_NUMBER));
    try std.testing.expect(!value.is(.VAL_OBJECT));

    value = Value{ .VAL_BOOL = true };
    try std.testing.expect(!value.is(.VAL_NULL));
    try std.testing.expect(value.is(.VAL_BOOL));
    try std.testing.expect(!value.is(.VAL_NUMBER));
    try std.testing.expect(!value.is(.VAL_OBJECT));

    value = Value{ .VAL_NUMBER = 1.0 };
    try std.testing.expect(!value.is(.VAL_NULL));
    try std.testing.expect(!value.is(.VAL_BOOL));
    try std.testing.expect(value.is(.VAL_NUMBER));
    try std.testing.expect(!value.is(.VAL_OBJECT));

    var obj = Object{ .object_type = .OBJ_FUNCTION };
    value = Value{ .VAL_OBJECT = &obj };
    try std.testing.expect(!value.is(.VAL_NULL));
    try std.testing.expect(!value.is(.VAL_BOOL));
    try std.testing.expect(!value.is(.VAL_NUMBER));
    try std.testing.expect(value.is(.VAL_OBJECT));
}

test "Can determine if value is falsey" {
    var value = Value{ .VAL_NULL = undefined };
    try std.testing.expect(value.isFalsey());

    value = Value{ .VAL_BOOL = true };
    try std.testing.expect(!value.isFalsey());
    value = Value{ .VAL_BOOL = false };
    try std.testing.expect(value.isFalsey());

    value = Value{ .VAL_NUMBER = 1.0 };
    try std.testing.expect(!value.isFalsey());

    var obj = Object{ .object_type = .OBJ_FUNCTION };
    value = Value{ .VAL_OBJECT = &obj };
    try std.testing.expect(!value.isFalsey());
}

test "Can determine equality" {
    var value = Value{ .VAL_NULL = undefined };
    try std.testing.expect(value.isEqual(Value{ .VAL_NULL = undefined }));

    value = Value{ .VAL_BOOL = true };
    try std.testing.expect(value.isEqual(value));
    try std.testing.expect(!value.isEqual(Value{ .VAL_BOOL = false }));

    value = Value{ .VAL_NUMBER = 1.0 };
    try std.testing.expect(value.isEqual(Value{ .VAL_NUMBER = 1.0 }));
    try std.testing.expect(!value.isEqual(Value{ .VAL_NUMBER = 2.0 }));

    // Object equality is tested in the object tests
}
