const std = @import("std");

const TestBase = @import("test_base.zig");
const ExpectedVariable = @import("test_base.zig").ExpectedVariable;
const Value = @import("../value.zig").Value;

test "if statement" {
    const expected = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 1 },
    };
    try TestBase.globalVariableBasedTest("var i = 0; if (true) i = 1;", &[_]ExpectedVariable {expected});
}

test "if else" {
    const expected = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 2 },
    };
    try TestBase.globalVariableBasedTest("var i = 0; if (false) i = 1; else i = 2;", &[_]ExpectedVariable {expected});
}

test "else if" {
    const expected = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 2 },
    };
    try TestBase.globalVariableBasedTest("var i = 0; if (false) i = 1; else if (true) i = 2; else i = 3;", &[_]ExpectedVariable {expected});
}
