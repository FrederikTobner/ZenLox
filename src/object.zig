const std = @import("std");

pub const ObjectType = enum {
    OBJ_STRING,
};

pub const Object = struct {
    object_type: ObjectType,
    pub fn as(self: *Object, comptime Type: type) !*Type {
        return @fieldParentPtr(Type, "object", self);
    }

    pub fn isEqual(self: *Object, other: *Object) !bool {
        if (self.object_type != other.object_type) {
            return false;
        }

        switch (self.object_type) {
            .OBJ_STRING => return (try self.as(ObjectString)).isEqual(try other.as(ObjectString)),
        }
    }

    pub fn print(self: *Object, writter: *const std.fs.File.Writer) !void {
        switch (self.object_type) {
            .OBJ_STRING => try (try self.as(ObjectString)).print(writter),
        }
    }

    pub fn printDebug(self: *Object) !void {
        switch (self.object_type) {
            .OBJ_STRING => (try self.as(ObjectString)).printDebug(),
        }
    }
};

pub const ObjectString = struct {
    object: Object,
    chars: []const u8,
    hash: u64,

    pub fn isEqual(self: *ObjectString, other: *ObjectString) bool {
        return self.chars.len == other.chars.len and std.mem.eql(u8, self.chars, other.chars);
    }

    pub fn print(self: *ObjectString, writter: *const std.fs.File.Writer) !void {
        try writter.print("{s}", .{self.chars});
    }

    pub fn printDebug(self: *ObjectString) void {
        std.debug.print("{s}", .{self.chars});
    }
};
