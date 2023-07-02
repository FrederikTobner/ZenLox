const std = @import("std");

/// The different types of objects
pub const ObjectType = enum {
    OBJ_STRING,
};

/// Base object type
pub const Object = struct {
    object_type: ObjectType,

    /// Casts the object to the given type
    pub fn as(self: *Object, comptime Type: type) *Type {
        return @fieldParentPtr(Type, "object", self);
    }

    /// Returns true if the object is equal to the other object, false otherwise
    pub fn isEqual(self: *Object, other: *Object) bool {
        if (self.object_type != other.object_type) {
            return false;
        }
        switch (self.object_type) {
            // Strings are uniqued, so we can just compare the pointers
            .OBJ_STRING => return self == other,
        }
    }

    /// Prints the object to stdout using the given `std.fs.File.Writer`
    pub fn print(self: *Object, writer: *const std.fs.File.Writer) !void {
        switch (self.object_type) {
            .OBJ_STRING => try self.as(ObjectString).print(writer),
        }
    }

    /// Print the object to stderr - only for debugging
    pub fn printDebug(self: *Object) void {
        switch (self.object_type) {
            .OBJ_STRING => self.as(ObjectString).printDebug(),
        }
    }
};

/// String object type
pub const ObjectString = struct {
    object: Object,
    chars: []const u8,
    hash: u64,

    /// Prints the string to stdout using the given `std.fs.File.Writer`
    pub fn print(self: *ObjectString, writer: *const std.fs.File.Writer) !void {
        try writer.print("{s}", .{self.chars});
    }

    /// Print the string to stderr - only for debugging
    pub fn printDebug(self: *ObjectString) void {
        std.debug.print("{s}", .{self.chars});
    }
};
