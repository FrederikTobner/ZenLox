const std = @import("std");

const TestBase = @import("test_base.zig");
const InterpreterError = @import("../virtual_machine.zig").InterpreterError;
const Value = @import("../value.zig").Value;

test "Can define global" {
    try TestBase.globalVariableBasedTest("var i = 5;", Value{ .VAL_NUMBER = 5 });
}

// Errors

test "undefined variable" {
    try TestBase.errorProducingTest("i = 5;", InterpreterError.RuntimeError);
}
