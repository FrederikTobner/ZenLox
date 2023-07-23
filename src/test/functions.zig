const std = @import("std");

const TestBase = @import("test_base.zig");
const InterpreterError = @import("../virtual_machine.zig").InterpreterError;
const Value = @import("../value.zig").Value;

test "function" {
    try TestBase.globalVariableBasedTest("fun add(a, b) { return a + b; } var i = add(1, 2);", Value{ .VAL_NUMBER = 3 });
}

test "function with global upvalue" {
    try TestBase.globalVariableBasedTest("var i = 3; fun inc() {i = i + 1;} inc();", Value{ .VAL_NUMBER = 4 });
}

test "function with closure upvalue" {
    try TestBase.globalVariableBasedTest("fun outer() {var x = 3; fun inc() {x = x + 1;} inc(); return x; } var i = outer();", Value{ .VAL_NUMBER = 4 });
}

test "function with twice captured closure upvalue" {
    try TestBase.globalVariableBasedTest("fun outer() {var x = 3; fun inc() {x = x + 1;} fun inc2() {x = x + 1;} inc(); inc2(); return x; } var i = outer();", Value{ .VAL_NUMBER = 5 });
}

// Errors

test "return at top level" {
    try TestBase.errorProducingTest("return 1;", InterpreterError.CompileError);
}

test "violate arrity" {
    try TestBase.errorProducingTest("fun add(a, b) { return a + b; } var i = add(1);", InterpreterError.RuntimeError);
}
