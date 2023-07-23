const std = @import("std");

const TestBase = @import("test_base.zig");
const Value = @import("../value.zig").Value;

test "Addition" {
    try TestBase.globalVariableBasedTest("var i = 3 + 2;", Value{ .VAL_NUMBER = 5 });
}

test "Subtraction" {
    try TestBase.globalVariableBasedTest("var i = 3 - 2;", Value{ .VAL_NUMBER = 1 });
}

test "Multiplication" {
    try TestBase.globalVariableBasedTest("var i = 3 * 2;", Value{ .VAL_NUMBER = 6 });
}

test "Division" {
    try TestBase.globalVariableBasedTest("var i = 3 / 2;", Value{ .VAL_NUMBER = 1.5 });
}

test "Greater" {
    try TestBase.globalVariableBasedTest("var i = 3 > 2;", Value{ .VAL_BOOL = true });
    try TestBase.globalVariableBasedTest("var i = 2 > 3;", Value{ .VAL_BOOL = false });
}

test "Greater Equal" {
    try TestBase.globalVariableBasedTest("var i = 3 >= 2;", Value{ .VAL_BOOL = true });
    try TestBase.globalVariableBasedTest("var i = 3 >= 3;", Value{ .VAL_BOOL = true });
    try TestBase.globalVariableBasedTest("var i = 2 >= 3;", Value{ .VAL_BOOL = false });
}

test "Less" {
    try TestBase.globalVariableBasedTest("var i = 3 < 2;", Value{ .VAL_BOOL = false });
    try TestBase.globalVariableBasedTest("var i = 2 < 3;", Value{ .VAL_BOOL = true });
}

test "Less Equal" {
    try TestBase.globalVariableBasedTest("var i = 3 <= 2;", Value{ .VAL_BOOL = false });
    try TestBase.globalVariableBasedTest("var i = 3 <= 3;", Value{ .VAL_BOOL = true });
    try TestBase.globalVariableBasedTest("var i = 2 <= 3;", Value{ .VAL_BOOL = true });
}

test "Equal" {
    try TestBase.globalVariableBasedTest("var i = 3 == 2;", Value{ .VAL_BOOL = false });
    try TestBase.globalVariableBasedTest("var i = 3 == 3;", Value{ .VAL_BOOL = true });
}

test "Not equal" {
    try TestBase.globalVariableBasedTest("var i = 3 != 2;", Value{ .VAL_BOOL = true });
    try TestBase.globalVariableBasedTest("var i = 3 != 3;", Value{ .VAL_BOOL = false });
}
