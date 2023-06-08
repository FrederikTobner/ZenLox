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

    pub fn fromBool(boolean: bool) Value {
        return Value{ .Bool = boolean };
    }

    pub fn fromNull() Value {
        return Value{ .Null = void };
    }
    pub fn print(self: Value, stdout: anytype) !void {
        switch (self) {
            .Null => {
                try stdout.print("null", .{});
            },
            .Bool => {
                try stdout.print("{}", .{self.Bool});
            },
            .Number => {
                try stdout.print("{}", .{self.Number});
            },
            .Obj => {
                try stdout.print("object", .{});
            },
        }
    }
};
