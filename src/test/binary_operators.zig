const std = @import("std");

const TestBase = @import("test_base.zig");
const ExpectedVariable = @import("test_base.zig").ExpectedVariable;
const InterpreterError = @import("../virtual_machine.zig").InterpreterError;
const Value = @import("../value.zig").Value;

test "Addition" {
    const expected = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 5 },
    };
    try TestBase.globalVariableBasedTest("var i = 3 + 2;", &[_]ExpectedVariable{expected});
}

test "Subtraction" {
    const expected = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 1 },
    };
    try TestBase.globalVariableBasedTest("var i = 3 - 2;", &[_]ExpectedVariable{expected});
}

test "Multiplication" {
    const expected = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 6 },
    };
    try TestBase.globalVariableBasedTest("var i = 3 * 2;", &[_]ExpectedVariable{expected});
}

test "Division" {
    const expected = ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_NUMBER = 1.5 },
    };
    try TestBase.globalVariableBasedTest("var i = 3 / 2;", &[_]ExpectedVariable{expected});
}

test "Greater" {
    const expected = &[_]ExpectedVariable{ ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_BOOL = true },
    }, ExpectedVariable{
        .name = "j",
        .value = Value{ .VAL_BOOL = false },
    }, ExpectedVariable{
        .name = "k",
        .value = Value{ .VAL_BOOL = false },
    } };
    try TestBase.globalVariableBasedTest("var i = 3 > 2; var j = 3 > 3; var k = 2 > 3;", expected);
}

test "Greater Equal" {
    const expected = &[_]ExpectedVariable{ ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_BOOL = true },
    }, ExpectedVariable{
        .name = "j",
        .value = Value{ .VAL_BOOL = true },
    }, ExpectedVariable{
        .name = "k",
        .value = Value{ .VAL_BOOL = false },
    } };
    try TestBase.globalVariableBasedTest("var i = 3 >= 2; var j = 3 >= 3; var k = 2 >= 3;", expected);
}

test "Less" {
     const expected = &[_]ExpectedVariable{ ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_BOOL = false },
    }, ExpectedVariable{
        .name = "j",
        .value = Value{ .VAL_BOOL = false },
    }, ExpectedVariable{
        .name = "k",
        .value = Value{ .VAL_BOOL = true },
    } };
    try TestBase.globalVariableBasedTest("var i = 3 < 2; var j = 3 < 3; var k = 2 < 3;", expected);
}

test "Less Equal" {
     const expected = &[_]ExpectedVariable{ ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_BOOL = false },
    }, ExpectedVariable{
        .name = "j",
        .value = Value{ .VAL_BOOL = true },
    }, ExpectedVariable{
        .name = "k",
        .value = Value{ .VAL_BOOL = true },
    } };
    try TestBase.globalVariableBasedTest("var i = 3 <= 2; var j = 3 <= 3; var k = 2 <= 3;", expected);
}

test "Equal" {
    const expected = &[_]ExpectedVariable{ ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_BOOL = false },
    }, ExpectedVariable{
        .name = "j",
        .value = Value{ .VAL_BOOL = true },
    }};
    try TestBase.globalVariableBasedTest("var i = 3 == 2; var j = 3 == 3;", expected);
}

test "Not equal" {
    const expected = &[_]ExpectedVariable{ ExpectedVariable{
        .name = "i",
        .value = Value{ .VAL_BOOL = true },
    }, ExpectedVariable{
        .name = "j",
        .value = Value{ .VAL_BOOL = false },
    }};
    try TestBase.globalVariableBasedTest("var i = 3 != 2; var j = 3 != 3;", expected);
}

// Erros

test "Addition on Boolean" {
    try TestBase.errorProducingTest("var i = 3 + true;", InterpreterError.RuntimeError);
}


test "Subtraction on Boolean" {
    try TestBase.errorProducingTest("var i = 3 - true;", InterpreterError.RuntimeError);
}


test "Multiplication on Boolean" {
    try TestBase.errorProducingTest("var i = 3 * true;", InterpreterError.RuntimeError);
}

test "Division on Boolean" {
    try TestBase.errorProducingTest("var i = 3 / true;", InterpreterError.RuntimeError);
}

test "Greater on Boolean" {
    try TestBase.errorProducingTest("var i = 3 > true;", InterpreterError.RuntimeError);
}

test "Greater equal on Boolean" {
    try TestBase.errorProducingTest("var i = 3 >= true;", InterpreterError.RuntimeError);
}

test "Less on Boolean" {
    try TestBase.errorProducingTest("var i = 3 < true;", InterpreterError.RuntimeError);
}

test "Less equal on Boolean" {
    try TestBase.errorProducingTest("var i = 3 <= true;", InterpreterError.RuntimeError);
}

