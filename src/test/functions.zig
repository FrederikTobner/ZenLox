const std = @import("std");

const TestBase = @import("test_base.zig");
const ExpectedVariable = @import("test_base.zig").ExpectedVariable;
const InterpreterError = @import("../virtual_machine.zig").InterpreterError;
const Value = @import("../value.zig").Value;

test "function" {
    const expectedVariable = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 3 },
    };
    try TestBase.globalVariableBasedTest("fun add(a, b) { return a + b; } var i = add(1, 2);", &[_]ExpectedVariable{expectedVariable});
}

test "function with global upvalue" {
    const expectedVariable = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 4 },
    };
    try TestBase.globalVariableBasedTest("var i = 3; fun inc() {i = i + 1;} inc();", &[_]ExpectedVariable{expectedVariable});
}

test "function with two global upvalues" {
    const expectedVariable = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 5 },
    };
    try TestBase.globalVariableBasedTest("var i = 3; var j = 4; fun inc() {i = j + 1;} inc();", &[_]ExpectedVariable{expectedVariable});
}

test "function with closure upvalue" {
    const expectedVariable = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 4 },
    };
    try TestBase.globalVariableBasedTest("fun outer() {var x = 3; fun inc() {x = x + 1;} inc(); return x; } var i = outer();", &[_]ExpectedVariable{expectedVariable});
}

test "function returning function" {
    const expected = &[_]ExpectedVariable{ ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 4 },
    }, ExpectedVariable{
        .name = "j",
        .value = Value{ .VAL_NUMBER = 5},
    }, ExpectedVariable{
        .name = "k",
        .value = Value{ .VAL_NUMBER = 6 },
    } };
    try TestBase.globalVariableBasedTest("fun outer() {var x = 3; fun inc() { return x = x + 1;} return inc; } var foo = outer(); var i = foo(); var j = foo(); var k = foo();", expected);
}


test "function with twice captured closure upvalue" {
    const expectedVariable = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 5 },
    };
    try TestBase.globalVariableBasedTest("fun outer() {var x = 3; fun inc() {x = x + 1;} fun inc2() {x = x + 1;} inc(); inc2(); return x; } var i = outer();", &[_]ExpectedVariable{expectedVariable});
}

// Errors

test "return at top level" {
    try TestBase.errorProducingTest("return 1;", InterpreterError.CompileError);
}

test "violate arrity" {
    try TestBase.errorProducingTest("fun add(a, b) { return a + b; } var i = add(1);", InterpreterError.RuntimeError);
}
