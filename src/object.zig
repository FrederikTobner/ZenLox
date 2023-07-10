const std = @import("std");

const Chunk = @import("chunk.zig");
const Value = @import("value.zig").Value;

/// The different types of objects
pub const ObjectType = enum {
    /// A string object
    OBJ_STRING,
    /// A function object
    OBJ_FUNCTION,
    /// A native function object
    OBJ_NATIVE_FUNCTION,
    /// A closure object
    OBJ_CLOSURE,
    /// An upvalue object
    OBJ_UPVALUE,
};

/// Base object type
pub const Object = struct {
    /// The type of the object
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
            // We could compare the bytecode, but that would be a lot of work
            .OBJ_FUNCTION => return self == other,
            // Native functions are equal if they have the same function pointer
            .OBJ_NATIVE_FUNCTION => return self == other,
            // Closures are equal if they have the same function and upvalues
            .OBJ_CLOSURE => {
                const self_closure = self.as(ObjectClosure);
                const other_closure = other.as(ObjectClosure);
                if (self_closure.function != other_closure.function) {
                    return false;
                }
                if (self_closure.upvalues.len != other_closure.upvalues.len) {
                    return false;
                }
                for (self_closure.upvalues) |self_upvalue, i| {
                    const other_upvalue = other_closure.upvalues[i];
                    if (self_upvalue != other_upvalue) {
                        return false;
                    }
                }
                return true;
            },
            // Upvalues are equal if the underlying value is equal
            .OBJ_UPVALUE => {
                const self_upvalue = self.as(ObjectUpvalue);
                const other_upvalue = other.as(ObjectUpvalue);
                return self_upvalue.closed.isEqual(other_upvalue.closed);
            },
        }
    }

    /// Prints the object to stdout using the given `std.fs.File.Writer`
    pub fn print(self: *Object, writer: *const std.fs.File.Writer) !void {
        switch (self.object_type) {
            .OBJ_STRING => try self.as(ObjectString).print(writer),
            .OBJ_FUNCTION => try self.as(ObjectFunction).print(writer),
            .OBJ_NATIVE_FUNCTION => try self.as(ObjectNativeFunction).print(writer),
            .OBJ_CLOSURE => try self.as(ObjectClosure).print(writer),
            .OBJ_UPVALUE => try self.as(ObjectUpvalue).print(writer),
        }
    }

    /// Print the object to stderr - only for debugging
    pub fn printDebug(self: *Object) void {
        switch (self.object_type) {
            .OBJ_STRING => self.as(ObjectString).printDebug(),
            .OBJ_FUNCTION => self.as(ObjectFunction).printDebug(),
            .OBJ_NATIVE_FUNCTION => self.as(ObjectNativeFunction).printDebug(),
            .OBJ_CLOSURE => self.as(ObjectClosure).function.printDebug(),
            .OBJ_UPVALUE => self.as(ObjectUpvalue).location.printDebug(),
        }
    }
};

/// String object type
pub const ObjectString = struct {
    /// The base object
    object: Object,
    /// The underlying character sequence
    chars: []const u8,
    /// The hash of the string
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

pub const ObjectFunction = struct {
    /// The base object
    object: Object,
    /// The arity of the function
    arity: u8,
    /// The chunk that was created from the function definition
    chunk: Chunk,
    /// The name of the function - empty for the main function
    name: []const u8,

    /// Prints the function to stdout using the given `std.fs.File.Writer`
    pub fn print(self: *ObjectFunction, writer: *const std.fs.File.Writer) !void {
        if (self.name.len > 0) {
            try writer.print("<fn {s}>", .{self.name});
        } else {
            try writer.print("<script>", .{});
        }
    }

    /// Print the function to stderr - only for debugging and error messages
    pub fn printDebug(self: *ObjectFunction) void {
        if (self.name.len > 0) {
            std.debug.print("<fn {s}>", .{self.name});
        } else {
            std.debug.print("<script>", .{});
        }
    }
};

pub const ObjectNativeFunction = struct {
    /// The base object
    object: Object,
    /// The arity of the function
    arity: u8,
    /// The function pointer
    function: *const fn ([]Value) Value,

    /// Prints the function to stdout using the given `std.fs.File.Writer`
    pub fn print(self: *ObjectNativeFunction, writer: *const std.fs.File.Writer) !void {
        _ = self;
        try writer.print("<native fn>", .{});
    }

    /// Print the function to stderr - only for debugging and error messages
    pub fn printDebug(self: *ObjectNativeFunction) void {
        _ = self;
        std.debug.print("<native fn>", .{});
    }
};

pub const ObjectClosure = struct {
    /// The base object
    object: Object,
    /// The function that was closed over
    function: *ObjectFunction,
    /// The upvalues that were closed over
    upvalues: []*ObjectUpvalue,

    /// Prints the closure to stdout using the given `std.fs.File.Writer`
    pub fn print(self: *ObjectClosure, writer: *const std.fs.File.Writer) !void {
        try self.function.print(writer);
    }

    /// Print the closure to stderr - only for debugging
    pub fn printDebug(self: *ObjectClosure) void {
        self.function.printDebug();
    }
};

pub const ObjectUpvalue = struct {
    /// The base object
    object: Object,
    /// The location of the upvalue
    location: *Value,
    /// The value of the upvalue
    closed: Value,
    /// The next upvalue in the linked list
    next: *ObjectUpvalue,

    /// Prints the upvalue to stdout using the given `std.fs.File.Writer`
    pub fn print(self: *ObjectUpvalue, writer: *const std.fs.File.Writer) !void {
        _ = self;
        try writer.print("upvalue", .{});
    }

    /// Print the upvalue to stderr - only for debugging
    pub fn printDebug(self: *ObjectUpvalue) void {
        _ = self;
        std.debug.print("upvalue", .{});
    }
};
