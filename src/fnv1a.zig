const ObjectString = @import("object.zig").ObjectString;

const fnv1a_offset_basis: u64 = 0x811c9dc5;
const fnv1a_prime: u64 = 0x1000193;

pub fn hash(chars: []const u8) u64 {
    var hash_value: u64 = fnv1a_offset_basis;
    for (chars) |char| {
        hash_value = hash_value ^ @as(u64, char);
        _ = @mulWithOverflow(u64, hash_value, fnv1a_prime, &hash_value);
    }
    return hash_value;
}
