const Object = @import("object.zig").Object;

pub const Type = enum { Null, Bool, Number, Obj };

// Tagged union that can hold any of the supported types.
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

    // Prints the value in the console using the given Writter.
    pub fn print(self: Value, stdout: anytype) !void {
        switch (self) {
            .Null => try stdout.print("null", .{}),
            .Bool => try stdout.print("{}", .{self.Bool}),
            .Number => try stdout.print("{d}", .{self.Number}),
            .Obj => try stdout.print("object", .{}),
        }
    }
};
