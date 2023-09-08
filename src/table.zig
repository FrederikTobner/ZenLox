/// This file contains the implementation of the hash table.
/// The hashtable uses linear probing to resolve collisions.
const std = @import("std");

const ObjectString = @import("object.zig").ObjectString;
const Value = @import("value.zig").Value;

/// A hash table using linear probing to resolve collisions.
const Table = @This();

/// The growth factor of the table.
const table_growth_factor = 2.0;
/// The maximum load factor of the table.
const table_max_load_factor = 0.75;
/// The initial capacity of the table.
const table_init_capacity = 8;

/// An entry in the table.
const Entry = struct {
    key: ?*ObjectString = null,
    value: Value = undefined,
};

/// The capacity of the table.
capacity: usize = 0,
/// The number of entries in the table.
count: usize = 0,
/// The entries of the table.
entries: []Entry = undefined,
/// The allocator used to allocate the entries.
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
pub fn set(self: *Table, key: *ObjectString, value: Value) !bool {
    const previousF: f64 = @floatFromInt(self.count);
    const currentF: f64 = @floatFromInt(self.capacity);
    if (previousF >= (currentF * table_max_load_factor)) {
        try self.adjustCapacity(self.growCapacy());
    }
    const entry: *Entry = findEntry(self.entries, self.capacity, key);
    const is_new_key = entry.key == null;
    if (is_new_key and entry.value.isEqual(Value{ .VAL_NULL = undefined })) {
        self.count += 1;
    }
    entry.*.key = key;
    entry.*.value = value;
    return is_new_key;
}

/// Gets the value associated with the given key.
/// Returns null if no entry associated with the key exists.
pub fn get(self: *Table, key: *ObjectString) ?Value {
    if (self.count == 0) {
        return null;
    }
    const entry = findEntry(self.entries, self.capacity, key);
    return if (entry.key != null) entry.value else null;
}

/// Gets the value associated with the given key.
pub fn getWithChars(self: *Table, chars: []const u8, hash: u64) ?Value {
    if (self.count == 0) {
        return null;
    }
    const entry = findString(self, chars, hash);
    return if (entry.key != null) entry.value else null;
}

/// Deletes the entry associated with the given key.
/// Returns true if the entry was deleted and false otherwise.
pub fn delete(self: *Table, key: *ObjectString) bool {
    if (self.count == 0) {
        return false;
    }
    const entry = findEntry(self.entries, self.capacity, key);
    if (entry.key == null) {
        return false;
    }
    // Placing a tombstone in the entry to mark it as deleted.
    entry.key = null;
    entry.value = Value{ .VAL_BOOL = true };
    return true;
}

/// Looks up the given key in the table.
/// Returns either the entry associated with the key or the first empty entry.
fn findEntry(entries: []Entry, capacity: usize, key: *ObjectString) *Entry {
    var index = @mod(key.hash, capacity);
    var tombstone: ?*Entry = null;
    while (true) {
        var entry: *Entry = &entries[index];
        if (entry.key) |entry_key| {
            if (entry_key.chars.len == key.chars.len and entry_key.hash == key.hash and std.mem.eql(u8, entry_key.chars, key.chars)) {
                return entry;
            }
        } else {
            switch (entry.value) {
                .VAL_NULL => return tombstone orelse entry,
                else => {
                    if (tombstone == null) {
                        tombstone = entry;
                    }
                },
            }
        }
        index = @mod((index + 1), capacity);
    }
}

/// Looks up the characters
fn findString(self: *Table, chars: []const u8, hash: u64) *Entry {
    var index = @mod(hash, self.capacity);
    var tombstone: ?*Entry = null;
    while (true) {
        var entry: *Entry = &self.entries[index];
        if (entry.key) |entry_key| {
            if (entry_key.chars.len == chars.len and entry_key.hash == hash and std.mem.eql(u8, entry_key.chars, chars)) {
                return entry;
            }
        } else {
            switch (entry.value) {
                .VAL_NULL => return tombstone orelse entry,
                else => {
                    if (tombstone == null) {
                        tombstone = entry;
                    }
                },
            }
        }
        index = @mod((index + 1), self.capacity);
    }
}

/// Adjusts the capacity of the table to the given capacity.
fn adjustCapacity(self: *Table, new_capacity: usize) !void {
    self.count = 0;
    var new_entries = try self.allocator.alloc(Entry, new_capacity);
    var start_index: usize = 0;
    // Initializing the new entries.
    while (start_index < new_capacity) {
        new_entries[start_index] = Entry{ .key = null, .value = Value{ .VAL_NULL = undefined } };
        start_index += 1;
    }
    if (self.capacity > 0) {
        // Copy the entries from the old table to the new table.
        for (self.entries) |entry| {
            if (entry.key) |entry_key| {
                const new_entry = findEntry(new_entries, new_capacity, entry_key);
                new_entry.key = entry_key;
                new_entry.value = entry.value;
                self.count += 1;
            }
            continue;
        }
        self.allocator.free(self.entries);
    }
    self.entries = new_entries;
    self.capacity = new_capacity;
}

/// Calculates the new capacity of the table.
fn growCapacy(self: *Table) usize {
    const capacityF: f64 = @floatFromInt(self.capacity);
    return if (capacityF * table_growth_factor > table_init_capacity) self.capacity * 2 else table_init_capacity;
}

test "Can get entries" {
    var table = Table.init(std.testing.allocator);
    defer table.deinit();
    var key = ObjectString{ .chars = "key", .hash = 123, .object = undefined };
    var value = Value{ .VAL_NUMBER = 1234.0 };
    _ = try table.set(&key, value);
    var returned_value = table.get(&key);
    try std.testing.expectEqual(value, returned_value.?);
}

test "Can find entry using character sequence" {
    var table = Table.init(std.testing.allocator);
    defer table.deinit();
    var key = ObjectString{ .chars = "key", .hash = 123, .object = undefined };
    var value = Value{ .VAL_NUMBER = 1234.0 };
    _ = try table.set(&key, value);
    var returned_value = table.getWithChars("key", 123);
    try std.testing.expectEqual(value, returned_value.?);
}

test "Can remove Entry" {
    var table = Table.init(std.testing.allocator);
    defer table.deinit();
    var key = ObjectString{ .chars = "key", .hash = 123, .object = undefined };
    _ = try table.set(&key, Value{ .VAL_NUMBER = 1234.0 });
    _ = table.delete(&key);
    var returned_value = table.get(&key);
    try std.testing.expect(null == returned_value);
}

test "Can find entry after adjusting capacity" {
    var table = Table.init(std.testing.allocator);
    defer table.deinit();
    var key = ObjectString{ .chars = "key", .hash = 123, .object = undefined };
    var value = Value{ .VAL_NUMBER = 1234.0 };
    _ = try table.set(&key, value);
    const capacity: f64 = @floatFromInt(table.capacity);
    try table.adjustCapacity(@intFromFloat(capacity * table_growth_factor));
    var returned_value = table.get(&key);
    try std.testing.expectEqual(value, returned_value.?);
}
