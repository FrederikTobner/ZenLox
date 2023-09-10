const std = @import("std");

const TestBase = @import("test_base.zig");
const ExpectedVariable = @import("test_base.zig").ExpectedVariable;
const InterpreterError = @import("../virtual_machine.zig").InterpreterError;
const Value = @import("../value.zig").Value;

test "Can define global" {
    const expectedVariable = ExpectedVariable.init("i", Value{ .VAL_NUMBER = 5 });
    try TestBase.globalVariableBasedTest("var i = 5;", &[_]ExpectedVariable{expectedVariable});
}

// Errors

test "undefined variable" {
    try TestBase.errorProducingTest("i = 5;", InterpreterError.RuntimeError);
}
