const std = @import("std");

const TestBase = @import("test_base.zig");
const ExpectedVariable = @import("test_base.zig").ExpectedVariable;
const Value = @import("../value.zig").Value;

test "while" {
    const expectedVariable = ExpectedVariable.init("i", Value{ .VAL_NUMBER = 3 });
    try TestBase.globalVariableBasedTest("var i = 0; while(i < 3) {i = i + 1;}", &[_]ExpectedVariable{expectedVariable});
}

test "for" {
    const expectedVariable = ExpectedVariable.init("i", Value{ .VAL_NUMBER = 2 });
    try TestBase.globalVariableBasedTest("var i = 0; for(var counter = 0; counter < 3; counter = counter + 1) {i = counter;}", &[_]ExpectedVariable{expectedVariable});
}
