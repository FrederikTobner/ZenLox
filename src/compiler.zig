const std = @import("std");

const Chunk = @import("chunk.zig");
const Lexer = @import("lexer.zig");
const OpCode = @import("chunk.zig").OpCode;
const TokenType = @import("token.zig").TokenType;
const Token = @import("token.zig");
const Value = @import("value.zig").Value;
const Object = @import("object.zig").Object;
const ObjectString = @import("object.zig").ObjectString;
const MemoryMutator = @import("memory_mutator.zig");

const Compiler = @This();
parser: Parser,
lexer: Lexer,
compiling_chunk: *Chunk = undefined,
print_bytecode: bool = @import("debug_options").printBytecode,
memory_mutator: *MemoryMutator = undefined,
rules: std.EnumArray(TokenType, ParseRule),
const Parser = struct {
    current: Token = undefined,
    previous: Token = undefined,
    had_error: bool = false,
    panic_mode: bool = false,
};

const Precedence = enum {
    PREC_NONE,
    PREC_ASSIGNMENT, // =
    PREC_OR, // or
    PREC_AND, // and
    PREC_EQUALITY, // == !=
    PREC_COMPARISON, // < > <= >=
    PREC_TERM, // + -
    PREC_FACTOR, // * /
    PREC_UNARY, // ! -
    PREC_CALL, // . ()
    PREC_PRIMARY,
};

const ParseRule = struct {
    prefix: ?*const fn (*Compiler, bool) std.mem.Allocator.Error!void = null,
    infix: ?*const fn (*Compiler, bool) std.mem.Allocator.Error!void = null,
    precedence: Precedence = Precedence.PREC_NONE,
};

// Maybe pass in the memory manager here?
pub fn init(memory_mutator: *MemoryMutator) Compiler {
    var rules = std.EnumArray(TokenType, ParseRule).initFill(ParseRule{});
    rules.set(.TOKEN_LEFT_PARENTHESIZE, ParseRule{ .prefix = grouping, .precedence = .PREC_CALL });
    rules.set(.TOKEN_MINUS, ParseRule{ .prefix = unary, .infix = binary, .precedence = .PREC_TERM });
    rules.set(.TOKEN_PLUS, ParseRule{ .infix = binary, .precedence = .PREC_TERM });
    rules.set(.TOKEN_SLASH, ParseRule{ .infix = binary, .precedence = .PREC_FACTOR });
    rules.set(.TOKEN_STAR, ParseRule{ .infix = binary, .precedence = .PREC_FACTOR });
    rules.set(.TOKEN_NUMBER, ParseRule{ .prefix = number });
    rules.set(.TOKEN_FALSE, ParseRule{ .prefix = literal });
    rules.set(.TOKEN_NULL, ParseRule{ .prefix = literal });
    rules.set(.TOKEN_TRUE, ParseRule{ .prefix = literal });
    rules.set(.TOKEN_BANG, ParseRule{ .prefix = unary });
    rules.set(.TOKEN_EQUAL_EQUAL, ParseRule{ .infix = binary, .precedence = .PREC_EQUALITY });
    rules.set(.TOKEN_BANG_EQUAL, ParseRule{ .infix = binary, .precedence = .PREC_EQUALITY });
    rules.set(.TOKEN_GREATER, ParseRule{ .infix = binary, .precedence = .PREC_COMPARISON });
    rules.set(.TOKEN_GREATER_EQUAL, ParseRule{ .infix = binary, .precedence = .PREC_COMPARISON });
    rules.set(.TOKEN_LESS, ParseRule{ .infix = binary, .precedence = .PREC_COMPARISON });
    rules.set(.TOKEN_LESS_EQUAL, ParseRule{ .infix = binary, .precedence = .PREC_COMPARISON });
    rules.set(.TOKEN_STRING, ParseRule{ .prefix = string });
    rules.set(.TOKEN_IDENTIFIER, ParseRule{ .prefix = variable });
    return Compiler{
        .parser = Parser{},
        .lexer = undefined,
        .memory_mutator = memory_mutator,
        .rules = rules,
    };
}

pub fn compile(self: *Compiler, source: []const u8, chunk: *Chunk) !bool {
    self.compiling_chunk = chunk;
    self.lexer = Lexer.init(source);
    self.advance();
    while (!self.match(.TOKEN_EOF)) {
        try self.declaration();
    }
    try self.endCompiler();
    if (self.print_bytecode) {
        self.getCompilingChunk().disassemble();
    }
    return !self.parser.had_error;
}

fn declaration(self: *Compiler) !void {
    if (self.match(.TOKEN_VAR)) {
        try self.varDeclaration();
    } else {
        try self.statement();
    }
    if (self.parser.panic_mode) {
        self.synchronize();
    }
}

fn varDeclaration(self: *Compiler) !void {
    const global: u24 = try self.parseVariable("Expect variable name.");
    if (self.match(.TOKEN_EQUAL)) {
        try self.expression();
    } else {
        try self.emitOpcode(OpCode.OP_NULL);
    }
    self.consume(.TOKEN_SEMICOLON, "Expect ';' after variable declaration.");
    try self.defineVariable(global);
}

fn parseVariable(self: *Compiler, error_message: []const u8) !u24 {
    self.consume(.TOKEN_IDENTIFIER, error_message);
    return try self.identifierConstant(self.parser.previous);
}

fn defineVariable(self: *Compiler, global: u24) !void {
    try self.emitIndexOpcode(global, .OP_DEFINE_GLOBAL, .OP_DEFINE_GLOBAL_LONG);
}

fn identifierConstant(self: *Compiler, name: Token) !u24 {
    return @intCast(u24, try self.makeConstant(try self.memory_mutator.createStringObjectValue(name.start[0..name.length])));
}

fn statement(self: *Compiler) !void {
    if (self.match(.TOKEN_PRINT)) {
        try self.printStatement();
    } else {
        try self.expressionStatement();
    }
}

fn printStatement(self: *Compiler) !void {
    try self.expression();
    self.consume(.TOKEN_SEMICOLON, "Expect ';' after value.");
    try self.emitOpcode(OpCode.OP_PRINT);
}

fn expressionStatement(self: *Compiler) !void {
    try self.expression();
    self.consume(.TOKEN_SEMICOLON, "Expect ';' after expression.");
    try self.emitOpcode(OpCode.OP_POP);
}

fn variable(self: *Compiler, can_assign: bool) !void {
    try self.namedVariable(self.parser.previous, can_assign);
}

fn namedVariable(self: *Compiler, name: Token, can_assign: bool) !void {
    _ = can_assign;
    const arg = try self.identifierConstant(name);
    if (self.match(.TOKEN_EQUAL)) {
        try self.expression();
        try self.emitIndexOpcode(arg, .OP_SET_GLOBAL, .OP_SET_GLOBAL_LONG);
    } else {
        try self.emitIndexOpcode(arg, .OP_GET_GLOBAL, .OP_GET_GLOBAL_LONG);
    }
}

fn synchronize(self: *Compiler) void {
    self.parser.panic_mode = false;
    while (self.parser.current.token_type != .TOKEN_EOF) {
        if (self.parser.previous.token_type == .TOKEN_SEMICOLON) {
            return;
        }
        switch (self.parser.current.token_type) {
            .TOKEN_CLASS => return,
            .TOKEN_FUN => return,
            .TOKEN_VAR => return,
            .TOKEN_FOR => return,
            .TOKEN_IF => return,
            .TOKEN_WHILE => return,
            .TOKEN_PRINT => return,
            .TOKEN_RETURN => return,
            else => {},
        }
        self.advance();
    }
}

fn advance(self: *Compiler) void {
    self.parser.previous = self.parser.current;
    while (true) {
        self.parser.current = self.lexer.scanToken();
        if (self.parser.current.token_type != .TOKEN_ERROR) {
            break;
        }
        self.emitErrorAtCurrent(self.parser.current.asLexeme());
    }
}

fn expression(self: *Compiler) !void {
    try self.parsePrecedence(.PREC_ASSIGNMENT);
}

fn number(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const num = std.fmt.parseFloat(f64, self.parser.previous.asLexeme()) catch {
        self.emitError("Could not parse number.");
        return;
    };
    try self.emitConstant(Value{ .VAL_NUMBER = num });
}

fn literal(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    switch (self.parser.previous.token_type) {
        .TOKEN_FALSE => try self.emitOpcode(.OP_FALSE),
        .TOKEN_NULL => try self.emitOpcode(.OP_NULL),
        .TOKEN_TRUE => try self.emitOpcode(.OP_TRUE),
        else => unreachable,
    }
}

fn string(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const lexeme = self.parser.previous.asLexeme();
    try self.emitConstant(try self.memory_mutator.createStringObjectValue(lexeme[1 .. lexeme.len - 1]));
}

fn emitConstant(self: *Compiler, value: Value) !void {
    const index = try self.makeConstant(value);
    try self.emitIndexOpcode(index, .OP_CONSTANT, .OP_CONSTANT_LONG);
}

inline fn makeConstant(self: *Compiler, value: Value) !usize {
    return @intCast(u24, try self.getCompilingChunk().addConstant(value));
}

fn grouping(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    try self.expression();
    self.consume(.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after expression.");
}

fn unary(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const operator_type = self.parser.previous.token_type;
    try self.parsePrecedence(.PREC_UNARY);
    switch (operator_type) {
        .TOKEN_MINUS => try self.emitOpcode(.OP_NEGATE),
        .TOKEN_BANG => try self.emitOpcode(.OP_NOT),
        else => unreachable,
    }
}

fn binary(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const token_type = self.parser.previous.token_type;
    const rule = self.getRule(token_type);
    try self.parsePrecedence(@intToEnum(Precedence, @enumToInt(rule.precedence) + 1));
    switch (token_type) {
        .TOKEN_PLUS => try self.emitOpcode(.OP_ADD),
        .TOKEN_MINUS => try self.emitOpcode(.OP_SUBTRACT),
        .TOKEN_STAR => try self.emitOpcode(.OP_MULTIPLY),
        .TOKEN_SLASH => try self.emitOpcode(.OP_DIVIDE),
        .TOKEN_BANG_EQUAL => try self.emitOpcode(.OP_NOT_EQUAL),
        .TOKEN_EQUAL_EQUAL => try self.emitOpcode(.OP_EQUAL),
        .TOKEN_GREATER => try self.emitOpcode(.OP_GREATER),
        .TOKEN_GREATER_EQUAL => try self.emitOpcode(.OP_GREATER_EQUAL),
        .TOKEN_LESS => try self.emitOpcode(.OP_LESS),
        .TOKEN_LESS_EQUAL => try self.emitOpcode(.OP_LESS_EQUAL),
        else => unreachable,
    }
}

inline fn getRule(self: *Compiler, token_type: TokenType) ParseRule {
    return self.rules.get(token_type);
}

fn parsePrecedence(self: *Compiler, precedence: Precedence) !void {
    self.advance();
    const prefixRule = self.getRule(self.parser.previous.token_type).prefix orelse {
        self.emitError("Expect expression.");
        return;
    };
    if (prefixRule == undefined) {
        self.emitError("Expect expression.");
        return;
    }
    const can_assign = @enumToInt(precedence) <= @enumToInt(Precedence.PREC_ASSIGNMENT);
    try prefixRule(self, can_assign);
    while (@enumToInt(precedence) <= @enumToInt(self.getRule(self.parser.current.token_type).precedence)) {
        self.advance();
        const infixRule = self.getRule(self.parser.previous.token_type).infix orelse {
            self.emitError("Expect expression.");
            return;
        };
        try infixRule(self, can_assign);
    }
    if (can_assign and self.match(.TOKEN_EQUAL)) {
        self.emitError("Invalid assignment target.");
    }
}

fn consume(self: *Compiler, token_type: TokenType, message: []const u8) void {
    if (self.parser.current.token_type == token_type) {
        self.advance();
        return;
    }
    self.emitErrorAtCurrent(message);
}

fn match(self: *Compiler, token_type: TokenType) bool {
    if (self.parser.current.token_type != token_type) {
        return false;
    }
    self.advance();
    return true;
}

inline fn emitError(self: *Compiler, message: []const u8) void {
    self.emitErrorAtCurrent(message);
}

inline fn emitErrorAtCurrent(self: *Compiler, message: []const u8) void {
    self.emitErrorAt(&self.parser.current, message);
}

fn emitErrorAt(self: *Compiler, token: *Token, message: []const u8) void {
    if (self.parser.panic_mode) {
        return;
    }
    self.parser.panic_mode = true;
    std.debug.print("[line {d}]Error", .{token.line});
    if (token.token_type == .TOKEN_EOF) {
        std.debug.print(" at end", .{});
    } else if (token.token_type == .TOKEN_ERROR) {
        // Nothing.
    } else {
        std.debug.print(" at '{s}'", .{token.asLexeme()});
    }
    std.debug.print(": {s}\n", .{message});
    self.parser.had_error = true;
}

inline fn emitByte(self: *Compiler, byte: u8) !void {
    try self.getCompilingChunk().writeByte(byte, self.parser.previous.line);
}

fn emitBytes(self: *Compiler, bytes: []const u8) !void {
    for (bytes) |byte| {
        try self.emitByte(byte);
    }
}

fn emitIndexOpcode(self: *Compiler, index: usize, short_opcode: OpCode, long_opcode: OpCode) !void {
    if (index > @intCast(usize, std.math.maxInt(u24))) {
        self.emitError("Too many constants in one chunk.");
        return;
    }
    // If the index is greater than the max u8, we need to use the long constant opcode.
    else if (index > @intCast(usize, std.math.maxInt(u8))) {
        try self.emitOpcode(long_opcode);
        try self.emitBytes(&[_]u8{ @intCast(u8, (index >> 16) & 0xFF), @intCast(u8, (index >> 8) & 0xFF), @intCast(u8, index) });
    }
    // Otherwise, we can use the normal constant opcode.
    else {
        try self.emitOpcode(short_opcode);
        try self.emitByte(@intCast(u8, index));
    }
}

inline fn emitOpcode(self: *Compiler, op_code: OpCode) !void {
    try self.emitByte(@enumToInt(op_code));
}

fn emitOpcodes(self: *Compiler, op_codes: []const OpCode) !void {
    for (op_codes) |op_code| {
        try self.emitByte(@enumToInt(op_code));
    }
}

inline fn emitReturn(self: *Compiler) !void {
    try self.emitByte(@enumToInt(OpCode.OP_RETURN));
}

inline fn endCompiler(self: *Compiler) !void {
    try self.emitReturn();
}

inline fn getCompilingChunk(self: *Compiler) *Chunk {
    return self.compiling_chunk;
}
