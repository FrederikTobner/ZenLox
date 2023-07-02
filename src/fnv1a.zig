const std = @import("std");

const ObjectString = @import("object.zig").ObjectString;

/// The offset basis for the FNV-1a algorithm.
const fnv1a_offset_basis: u64 = 0xcbf29ce484222325;
/// The prime for the FNV-1a algorithm.
const fnv1a_prime: u64 = 0x00000100000001B3;

/// Hashes a string using the FNV-1a algorithm.
pub fn hash(chars: []const u8) u64 {
    var hash_value: u64 = fnv1a_offset_basis;
    for (chars) |char| {
        hash_value = hash_value ^ @as(u64, char);
        _ = @mulWithOverflow(u64, hash_value, fnv1a_prime, &hash_value);
    }
    return hash_value;
}

test "Hashes properly" {
    const hashedString: []const u8 = "test";
    const expected_hash: u64 = 0xf9e6e6ef197c2b25;
    try std.testing.expectEqual(expected_hash, hash(hashedString));
}
