const std = @import("std");

const Chunk = @import("chunk.zig");
const fnv1a = @import("fnv1a.zig");
const Object = @import("object.zig").Object;
const ObjectType = @import("object.zig").ObjectType;
const ObjectString = @import("object.zig").ObjectString;
const ObjectFunction = @import("object.zig").ObjectFunction;
const Table = @import("table.zig");
const Value = @import("value.zig").Value;

/// The MemoryMutator is responsible for allocating memory for the VM.
/// When the mutator is deinitialized, it will free all memory allocated
const MemoryMutator = @This();

allocator: std.mem.Allocator = undefined,
objects: std.ArrayList(*Object),
strings: Table,
globals: Table,

/// Initialize the MemoryMutator with the given allocator
pub fn init(allocator: std.mem.Allocator) MemoryMutator {
    return MemoryMutator{
        .allocator = allocator,
        .objects = std.ArrayList(*Object).init(allocator),
        .strings = Table.init(allocator),
        .globals = Table.init(allocator),
    };
}

/// Deinitialize the MemoryMutator, freeing all memory allocated
pub fn deinit(self: *MemoryMutator) !void {
    for (self.objects.items) |object| {
        switch (object.object_type) {
            .OBJ_STRING => try self.destroyStringObject(object.as(ObjectString)),
            .OBJ_FUNCTION => try self.destroyFunctionObject(object.as(ObjectFunction)),
        }
    }
    self.objects.deinit();
    self.strings.deinit();
    self.globals.deinit();
}

/// Allocate a new ObjectString with the given chars
pub fn createStringObjectValue(self: *MemoryMutator, chars: []const u8) !Value {
    var object_string = try self.allocator.create(ObjectString);
    object_string.chars = try self.allocator.dupe(u8, chars);
    object_string.hash = fnv1a.hash(chars);
    object_string.object.object_type = ObjectType.OBJ_STRING;
    const interned = self.strings.get(object_string);
    if (interned) |in| {
        try self.destroyStringObject(object_string);
        return in;
    }
    try self.objects.append(&(object_string.object));
    const result = Value{ .VAL_OBJECT = &(object_string.object) };
    _ = try self.strings.set(object_string, result);
    return result;
}

pub fn createFunctionObject(self: *MemoryMutator, name: []const u8) !*ObjectFunction {
    // We could intern chunks as well in the future but we should hash them
    // based on the opcodes to avoid long compile times
    var object_function = try self.allocator.create(ObjectFunction);
    object_function.arity = 0;
    object_function.chunk = Chunk.init(self.allocator);
    object_function.object.object_type = ObjectType.OBJ_FUNCTION;
    object_function.name = name;
    try self.objects.append(&(object_function.object));
    return object_function;
}

/// Allocate a new ObjectString by concatenating the given ObjectStrings
pub fn concatenateStringObjects(self: *MemoryMutator, left: *ObjectString, right: *ObjectString) !Value {
    var chars: []u8 = try self.allocator.alloc(u8, left.chars.len + right.chars.len);
    std.mem.copy(u8, chars, left.chars);
    var offset: usize = left.chars.len;
    while (offset < chars.len) : (offset += 1) {
        chars[offset] = right.chars[offset - left.chars.len];
    }
    var object_string = try self.allocator.create(ObjectString);
    object_string.chars = chars;
    object_string.hash = fnv1a.hash(chars);
    object_string.object.object_type = ObjectType.OBJ_STRING;
    const interned = self.strings.get(object_string);
    if (interned) |interned_string| {
        try self.destroyStringObject(object_string);
        return interned_string;
    }
    try self.objects.append(&(object_string.object));
    return Value{ .VAL_OBJECT = &(object_string.object) };
}

/// Free the memory allocated for the given ObjectString
pub fn destroyStringObject(self: *MemoryMutator, string_object: *ObjectString) !void {
    self.allocator.free(string_object.chars);
    self.allocator.destroy(string_object);
}

/// Free the memory allocated for the given ObjectString
pub fn destroyFunctionObject(self: *MemoryMutator, function_object: *ObjectFunction) !void {
    function_object.chunk.deinit();
    self.allocator.destroy(function_object);
}
