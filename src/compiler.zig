const std = @import("std");

const Chunk = @import("chunk.zig");
const Lexer = @import("lexer.zig");
const OpCode = @import("chunk.zig").OpCode;
const TokenType = @import("token.zig").TokenType;
const Token = @import("token.zig");
const Value = @import("value.zig").Value;

const Compiler = @This();
parser: Parser,
lexer: Lexer,
compiling_chunk: *Chunk = undefined,
print_bytecode: bool = @import("debug_options").printBytecode,

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
    prefix: ?*const fn (*Compiler) std.mem.Allocator.Error!void = null,
    infix: ?*const fn (*Compiler) std.mem.Allocator.Error!void = null,
    precedence: Precedence = Precedence.PREC_NONE,
};

// Creates an array keyed by the enum values.
var rules = std.EnumArray(TokenType, ParseRule).initFill(ParseRule{});

fn initRules() void {
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
}

pub fn init() Compiler {
    initRules();
    return Compiler{
        .parser = Parser{},
        .lexer = undefined,
    };
}

pub fn compile(self: *Compiler, source: []const u8, chunk: *Chunk) !bool {
    self.compiling_chunk = chunk;
    self.lexer = Lexer.init(source);
    self.advance();
    try self.expression();
    self.consume(.TOKEN_EOF, "Expect end of expression.");
    try self.endCompiler();
    if (self.print_bytecode) {
        self.getCompilingChunk().disassemble();
    }
    return !self.parser.had_error;
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

fn number(self: *Compiler) !void {
    const num = std.fmt.parseFloat(f64, self.parser.previous.asLexeme()) catch {
        self.emitError("Could not parse number.");
        return;
    };
    try self.emitConstant(Value{ .VAL_NUMBER = num });
}

fn literal(self: *Compiler) !void {
    switch (self.parser.previous.token_type) {
        .TOKEN_FALSE => try self.emitOpcode(OpCode.OP_FALSE),
        .TOKEN_NULL => try self.emitOpcode(OpCode.OP_NULL),
        .TOKEN_TRUE => try self.emitOpcode(OpCode.OP_TRUE),
        else => unreachable,
    }
}

fn emitConstant(self: *Compiler, value: Value) !void {
    const index = try self.makeConstant(value);
    if (index > @intCast(usize, std.math.maxInt(u24))) {
        self.emitError("Too many constants in one chunk.");
        return;
    }
    // If the index is greater than the max u8, we need to use the long constant opcode.
    else if (index > @intCast(usize, std.math.maxInt(u8))) {
        try self.emitOpcode(OpCode.OP_CONSTANT_LONG);
        try self.emitBytes(&[_]u8{ @intCast(u8, (index >> 16) & 0xFF), @intCast(u8, (index >> 8) & 0xFF), @intCast(u8, index) });
    }
    // Otherwise, we can use the normal constant opcode.
    else {
        try self.emitOpcode(OpCode.OP_CONSTANT);
        try self.emitByte(@intCast(u8, index));
    }
}

inline fn makeConstant(self: *Compiler, value: Value) !usize {
    return @intCast(u24, try self.getCompilingChunk().addConstant(value));
}

fn grouping(self: *Compiler) !void {
    try self.expression();
    self.consume(.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after expression.");
}

fn unary(self: *Compiler) !void {
    const operator_type = self.parser.previous.token_type;
    try self.parsePrecedence(.PREC_UNARY);
    switch (operator_type) {
        .TOKEN_MINUS => try self.emitOpcode(OpCode.OP_NEGATE),
        .TOKEN_BANG => try self.emitOpcode(OpCode.OP_NOT),
        else => unreachable,
    }
}

fn binary(self: *Compiler) !void {
    const token_type = self.parser.previous.token_type;
    const rule = getRule(token_type);
    try self.parsePrecedence(@intToEnum(Precedence, @enumToInt(rule.precedence) + 1));
    switch (token_type) {
        .TOKEN_PLUS => try self.emitOpcode(OpCode.OP_ADD),
        .TOKEN_MINUS => try self.emitOpcode(OpCode.OP_SUBTRACT),
        .TOKEN_STAR => try self.emitOpcode(OpCode.OP_MULTIPLY),
        .TOKEN_SLASH => try self.emitOpcode(OpCode.OP_DIVIDE),
        .TOKEN_BANG_EQUAL => try self.emitOpcode(OpCode.OP_NOT_EQUAL),
        .TOKEN_EQUAL_EQUAL => try self.emitOpcode(OpCode.OP_EQUAL),
        .TOKEN_GREATER => try self.emitOpcode(OpCode.OP_GREATER),
        .TOKEN_GREATER_EQUAL => try self.emitOpcode(OpCode.OP_GREATER_EQUAL),
        .TOKEN_LESS => try self.emitOpcode(OpCode.OP_LESS),
        .TOKEN_LESS_EQUAL => try self.emitOpcode(OpCode.OP_LESS_EQUAL),
        else => unreachable,
    }
}

inline fn getRule(token_type: TokenType) ParseRule {
    return rules.get(token_type);
}

fn parsePrecedence(self: *Compiler, precedence: Precedence) !void {
    self.advance();
    const prefixRule = getRule(self.parser.previous.token_type).prefix orelse {
        self.emitError("Expect expression.");
        return;
    };
    if (prefixRule == undefined) {
        self.emitError("Expect expression.");
        return;
    }
    try prefixRule(self);
    while (@enumToInt(precedence) <= @enumToInt(getRule(self.parser.current.token_type).precedence)) {
        self.advance();
        const infixRule = getRule(self.parser.previous.token_type).infix orelse {
            self.emitError("Expect expression.");
            return;
        };
        try infixRule(self);
    }
}

inline fn consume(self: *Compiler, token_type: TokenType, message: []const u8) void {
    if (self.parser.current.token_type == token_type) {
        self.advance();
        return;
    }
    self.emitErrorAtCurrent(message);
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
    std.debug.print("[line {d}]Error: ", .{token.line});
    if (token.token_type == TokenType.TOKEN_EOF) {
        std.debug.print(" at end", .{});
    } else if (token.token_type == TokenType.TOKEN_ERROR) {
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

fn emitOpcode(self: *Compiler, op_code: OpCode) !void {
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

fn getCompilingChunk(self: *Compiler) *Chunk {
    return self.compiling_chunk;
}
