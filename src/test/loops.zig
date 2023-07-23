const std = @import("std");

const TestBase = @import("test_base.zig");
const Value = @import("../value.zig").Value;

test "while" {
    try TestBase.globalVariableBasedTest("var i = 0; while(i < 3) {i = i + 1;} ", Value{ .VAL_NUMBER = 3 });
}

test "for" {
    try TestBase.globalVariableBasedTest("var i = 0; for(var counter = 0; counter < 3; counter = counter + 1) {i = counter;} ", Value{ .VAL_NUMBER = 2 });
}
