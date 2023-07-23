const std = @import("std");

const TestBase = @import("test_base.zig");
const Value = @import("../value.zig").Value;

test "if statement" {
    try TestBase.globalVariableBasedTest("var i = 0; if (true) i = 1;", Value{ .VAL_NUMBER = 1 });
}

test "if else" {
    try TestBase.globalVariableBasedTest("var i = 0; if (false) i = 1; else i = 2;", Value{ .VAL_NUMBER = 2 });
}

test "else if" {
    try TestBase.globalVariableBasedTest("var i = 0; if (false) i = 1; else if (true) i = 2; else i = 3;", Value{ .VAL_NUMBER = 2 });
}
