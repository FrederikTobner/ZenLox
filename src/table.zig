/// This file contains the implementation of the hash table.
/// The hashtable uses linear probing to resolve collisions.
const std = @import("std");

const ObjectString = @import("object.zig").ObjectString;
const Value = @import("value.zig").Value;

const Table = @This();

const table_growth_factor = 2.0;
const table_max_load_factor = 0.75;
const table_init_capacity = 8;

const Entry = struct {
    key: ?*ObjectString = null,
    value: Value = undefined,
};

capacity: usize = 0,
count: usize = 0,
entries: []Entry = undefined,
allocator: std.mem.Allocator = undefined,

/// Initializes the table with the given `allocator`.
pub fn init(allocator: std.mem.Allocator) Table {
    return Table{ .allocator = allocator };
}

/// Deinitializes the table.
pub fn deinit(self: *Table) void {
    if (self.capacity > 0) {
        self.allocator.free(self.entries);
        self.capacity = 0;
        self.count = 0;
    }
}

/// Sets the given key to the given value.
pub fn set(self: *Table, key: *ObjectString, value: Value) bool {
    if (self.count >= (@intToFloat(f64, self.capacity) * table_max_load_factor)) {
        self.adjustCapacity(self.growCapacy());
    }
    const entry = self.findEntry(key);
    const is_new_key = entry.key == null;
    if (is_new_key and entry.value == Value{ .VAL_NULL = undefined }) {
        self.count += 1;
    }
    entry.key = key;
    entry.value = value;
    return is_new_key;
}

/// Gets the value associated with the given key.
/// Returns null if no entry associated with the key exists.
pub fn get(self: *Table, key: *ObjectString) ?Value {
    if (self.count == 0) {
        return null;
    }
    const entry = self.findEntry(key);
    return if (entry.key != null) entry.value else null;
}

/// Deletes the entry associated with the given key.
/// Returns true if the entry was deleted and false otherwise.
pub fn delete(self: *Table, key: *ObjectString) bool {
    if (self.count == 0) {
        return false;
    }
    const entry = self.findEntry(key);
    if (entry.key == null) {
        return false;
    }
    entry.key = null;
    entry.value = Value{ .VAL_NULL = undefined };
    return true;
}

/// Looks up the given key in the table.
/// Returns either the entry associated with the key or the first empty entry.
fn findEntry(self: *Table, key: *ObjectString) *Entry {
    var index = @mod(key.hash, self.capacity);
    var tombstone: ?*Entry = null;
    while (true) {
        var entry = self.entries[index];
        if (entry.key == null) {
            switch (entry.value) {
                .VAL_NULL => return tombstone orelse &entry,
                else => {
                    if (tombstone == null) {
                        tombstone = &entry;
                    }
                },
            }
        } else if (entry.key.?.isEqual(key)) {
            return &entry;
        }
        index = @mod((index + 1), self.capacity);
    }
}

/// Looks up the characters
fn findString(self: *Table, chars: []const u8, hash: u32) ?*Entry {
    if (self.count == 0) {
        return null;
    }
    var index = @mod(hash, self.capacity);
    var tombstone: ?*Entry = null;
    while (true) {
        var entry = self.entries[index];
        if (entry.key == null) {
            switch (entry.value) {
                .VAL_NULL => return tombstone orelse &entry,
                else => {
                    if (tombstone == null) {
                        tombstone = entry;
                    }
                },
            }
        } else if (entry.key.length == chars.len and entry.key.hash == hash and std.mem.eql(u8, entry.key.chars, chars)) {
            return &entry;
        }
        index = @mod((index + 1), self.capacity);
    }
}

/// Adjusts the capacity of the table to the given capacity.
fn adjustCapacity(self: *Table, new_capacity: usize) void {
    self.count = 0;
    const new_entries = try self.allocater.alloc(Entry, new_capacity);
    for (new_entries) |entry| {
        entry.key = null;
        entry.value = Value{ .VAL_NULL = undefined };
    }
    for (self.entries) |entry| {
        if (entry.key == null) {
            continue;
        }
        const new_entry = new_entries.findEntry(entry.key);
        new_entry.key = entry.key;
        new_entry.value = entry.value;
        self.count += 1;
    }
    self.allocator.free(self.entries);
    self.entries = new_entries;
    self.capacity = new_capacity;
}

/// Calculates the new capacity of the table.
fn growCapacy(self: *Table) usize {
    return if (@intToFloat(f64, self.capacity) * table_growth_factor > table_init_capacity) self.capacity * 2 else table_init_capacity;
}
