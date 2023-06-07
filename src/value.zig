const Object = @import("object.zig").Object;

pub const Type = enum { Null, Bool, Number, Obj };

pub const Value = union(Type) {
    Null: void,
    Bool: bool,
    Number: f64,
    Obj: *Object,

    pub fn fromNumber(number: f64) Value {
        return Value{ .Number = number };
    }
};
