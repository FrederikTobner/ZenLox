const std = @import("std");
const Value = @import("value.zig").Value;
const Object = @import("object.zig").Object;
const ObjectType = @import("object.zig").ObjectType;
const ObjectString = @import("object.zig").ObjectString;

const MemoryMutator = @This();

allocator: std.mem.Allocator = undefined,
objects: std.ArrayList(*Object) = undefined,

pub fn init(allocator: std.mem.Allocator) MemoryMutator {
    return MemoryMutator{
        .allocator = allocator,
        .objects = std.ArrayList(*Object).init(allocator),
    };
}

pub fn deinit(self: *MemoryMutator) !void {
    var counter: usize = 0;
    while (counter < self.objects.items.len) : (counter += 1) {
        var object: *Object = self.objects.items[counter];
        if (object.object_type == ObjectType.OBJ_STRING) {
            try self.destroyStringObject(object);
        }
    }
    self.objects.deinit();
}

pub fn createStringObjectValue(self: *MemoryMutator, chars: []const u8) !Value {
    var object_string = try self.allocator.create(ObjectString);
    object_string.chars = try self.allocator.dupe(u8, chars);
    try self.objects.append(&(object_string.object));
    return Value{ .VAL_OBJECT = &(object_string.object) };
}

pub fn concatenateStringObjects(self: *MemoryMutator, left: *ObjectString, right: *ObjectString) !Value {
    var chars: []u8 = try self.allocator.alloc(u8, left.chars.len + right.chars.len);
    std.mem.copy(u8, chars, left.chars);
    var offset: usize = left.chars.len;
    while (offset < chars.len) : (offset += 1) {
        chars[offset] = right.chars[offset - left.chars.len];
    }
    var object_string = try self.allocator.create(ObjectString);
    object_string.chars = chars;
    try self.objects.append(&(object_string.object));
    return Value{ .VAL_OBJECT = &(object_string.object) };
}

pub fn destroyStringObject(self: *MemoryMutator, object: *Object) !void {
    var string_object: *ObjectString = try object.as(ObjectString);
    self.allocator.free(string_object.chars);
    self.allocator.destroy(string_object);
}