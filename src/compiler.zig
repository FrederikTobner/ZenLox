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
print_bytecode: bool = false,

const Parser = struct {
    current: Token,
    previous: Token,
    hadError: bool = false,
    panicMode: bool = false,
};

const Precedence = enum {
    NONE,
    ASSIGNMENT, // =
    OR, // or
    AND, // and
    EQUALITY, // == !=
    COMPARISON, // < > <= >=
    TERM, // + -
    FACTOR, // * /
    UNARY, // ! -
    CALL, // . ()
    PRIMARY,
};

const ParseRule = struct {
    prefix: ?*const fn (*Compiler) std.mem.Allocator.Error!void = null,
    infix: ?*const fn (*Compiler) std.mem.Allocator.Error!void = null,
    precedence: Precedence = Precedence.NONE,
};

// Creates an array keyed by the enum values.
var rules = std.EnumArray(TokenType, ParseRule).initFill(ParseRule{});

fn initRules() void {
    rules.set(TokenType.LEFT_PARENTHESIZE, ParseRule{ .prefix = grouping, .precedence = Precedence.CALL });
    rules.set(TokenType.RIGHT_PARENTHESIZE, ParseRule{});
    rules.set(TokenType.LEFT_BRACE, ParseRule{});
    rules.set(TokenType.RIGHT_BRACE, ParseRule{});
    rules.set(TokenType.COMMA, ParseRule{});
    rules.set(TokenType.DOT, ParseRule{});
    rules.set(TokenType.MINUS, ParseRule{ .prefix = unary, .infix = binary, .precedence = Precedence.TERM });
    rules.set(TokenType.PLUS, ParseRule{ .infix = binary, .precedence = Precedence.TERM });
    rules.set(TokenType.SEMICOLON, ParseRule{});
    rules.set(TokenType.SLASH, ParseRule{ .infix = binary, .precedence = Precedence.FACTOR });
    rules.set(TokenType.STAR, ParseRule{ .infix = binary, .precedence = Precedence.FACTOR });
    rules.set(TokenType.BANG, ParseRule{});
    rules.set(TokenType.BANG_EQUAL, ParseRule{});
    rules.set(TokenType.EQUAL, ParseRule{});
    rules.set(TokenType.EQUAL_EQUAL, ParseRule{});
    rules.set(TokenType.GREATER, ParseRule{});
    rules.set(TokenType.GREATER_EQUAL, ParseRule{});
    rules.set(TokenType.LESS, ParseRule{});
    rules.set(TokenType.LESS_EQUAL, ParseRule{});
    rules.set(TokenType.IDENTIFIER, ParseRule{});
    rules.set(TokenType.STRING, ParseRule{});
    rules.set(TokenType.NUMBER, ParseRule{ .prefix = number });
    rules.set(TokenType.AND, ParseRule{});
    rules.set(TokenType.CLASS, ParseRule{});
    rules.set(TokenType.ELSE, ParseRule{});
    rules.set(TokenType.FALSE, ParseRule{});
    rules.set(TokenType.FUN, ParseRule{});
    rules.set(TokenType.FOR, ParseRule{});
    rules.set(TokenType.IF, ParseRule{});
    rules.set(TokenType.NULL, ParseRule{});
    rules.set(TokenType.OR, ParseRule{});
    rules.set(TokenType.PRINT, ParseRule{});
    rules.set(TokenType.RETURN, ParseRule{});
    rules.set(TokenType.SUPER, ParseRule{});
    rules.set(TokenType.THIS, ParseRule{});
    rules.set(TokenType.TRUE, ParseRule{});
    rules.set(TokenType.VAR, ParseRule{});
    rules.set(TokenType.WHILE, ParseRule{});
    rules.set(TokenType.ERROR, ParseRule{});
    rules.set(TokenType.EOF, ParseRule{});
}

pub fn init() Compiler {
    initRules();
    return Compiler{
        .parser = Parser{
            .current = undefined,
            .previous = undefined,
        },
        .lexer = undefined,
    };
}

pub fn compile(self: *Compiler, source: []const u8, chunk: *Chunk) !bool {
    self.compiling_chunk = chunk;
    self.lexer = Lexer.init(source);
    self.advance();
    try self.expression();
    self.consume(TokenType.EOF, "Expect end of expression.");
    try self.endCompiler();
    return !self.parser.hadError;
}

fn advance(self: *Compiler) void {
    self.parser.previous = self.parser.current;
    while (true) {
        self.parser.current = self.lexer.scanToken();
        if (self.parser.current.tokenType != TokenType.ERROR) {
            break;
        }
        self.emitErrorAtCurrent(self.parser.current.asLexeme());
    }
}

fn expression(self: *Compiler) !void {
    try self.parsePrecedence(Precedence.ASSIGNMENT);
}

fn number(self: *Compiler) !void {
    const num = std.fmt.parseFloat(f64, self.parser.previous.asLexeme()) catch {
        self.emitError("Could not parse number.");
        return;
    };
    try self.emitConstant(Value{ .Number = num });
}

fn emitConstant(self: *Compiler, value: Value) !void {
    try self.getCompilingChunk().addConstant(value);
}

fn grouping(self: *Compiler) !void {
    try self.expression();
    self.consume(TokenType.RIGHT_PARENTHESIZE, "Expect ')' after expression.");
}

fn unary(self: *Compiler) !void {
    const operatorType = self.parser.previous.tokenType;
    try self.parsePrecedence(Precedence.UNARY);
    switch (operatorType) {
        TokenType.MINUS => try self.emitByte(@enumToInt(OpCode.OP_NEGATE)),
        else => unreachable,
    }
}

fn binary(self: *Compiler) !void {
    const operatorType = self.parser.previous.tokenType;
    const rule = getRule(operatorType);
    try self.parsePrecedence(@intToEnum(Precedence, @enumToInt(rule.precedence) + 1));
    switch (operatorType) {
        TokenType.PLUS => try self.emitByte(@enumToInt(OpCode.OP_ADD)),
        TokenType.MINUS => try self.emitByte(@enumToInt(OpCode.OP_SUBTRACT)),
        TokenType.STAR => try self.emitByte(@enumToInt(OpCode.OP_MULTIPLY)),
        TokenType.SLASH => try self.emitByte(@enumToInt(OpCode.OP_DIVIDE)),
        else => unreachable,
    }
}

fn getRule(tokenType: TokenType) ParseRule {
    return rules.get(tokenType);
}

fn parsePrecedence(self: *Compiler, precedence: Precedence) !void {
    self.advance();
    const prefixRule = getRule(self.parser.previous.tokenType).prefix orelse {
        self.emitError("Expect expression.");
        return;
    };
    if (prefixRule == undefined) {
        self.emitError("Expect expression.");
        return;
    }
    try prefixRule(self);
    while (@enumToInt(precedence) <= @enumToInt(getRule(self.parser.current.tokenType).precedence)) {
        self.advance();
        const infixRule = getRule(self.parser.previous.tokenType).infix orelse {
            self.emitError("Expect expression.");
            return;
        };
        try infixRule(self);
    }
}

inline fn consume(self: *Compiler, tokenType: TokenType, message: []const u8) void {
    if (self.parser.current.tokenType == tokenType) {
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
    if (self.parser.panicMode) {
        return;
    }
    self.parser.panicMode = true;
    std.debug.print("[line {d}]Error: ", .{token.line});
    if (token.tokenType == TokenType.EOF) {
        std.debug.print(" at end", .{});
    } else if (token.tokenType == TokenType.ERROR) {
        // Nothing.
    } else {
        std.debug.print(" at '{s}'", .{token.asLexeme()});
    }
    std.debug.print(": {s}\n", .{message});
    self.parser.hadError = true;
}

inline fn endCompiler(self: *Compiler) !void {
    try self.emitReturn();
}

inline fn emitReturn(self: *Compiler) !void {
    try self.emitByte(@enumToInt(OpCode.OP_RETURN));
}

fn getCompilingChunk(self: *Compiler) *Chunk {
    return self.compiling_chunk;
}

inline fn emitByte(self: *Compiler, byte: u8) !void {
    try self.getCompilingChunk().writeByte(byte, self.parser.previous.line);
}

fn emitBytes(self: *Compiler, byte1: u8, byte2: u8) !void {
    try self.emitByte(byte1);
    try self.emitByte(byte2);
}
