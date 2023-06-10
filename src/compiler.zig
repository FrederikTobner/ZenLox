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
    rules.set(.LEFT_PARENTHESIZE, ParseRule{ .prefix = grouping, .precedence = .CALL });
    rules.set(.MINUS, ParseRule{ .prefix = unary, .infix = binary, .precedence = .TERM });
    rules.set(.PLUS, ParseRule{ .infix = binary, .precedence = .TERM });
    rules.set(.SLASH, ParseRule{ .infix = binary, .precedence = .FACTOR });
    rules.set(.STAR, ParseRule{ .infix = binary, .precedence = .FACTOR });
    rules.set(.NUMBER, ParseRule{ .prefix = number });
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
    self.consume(.EOF, "Expect end of expression.");
    try self.endCompiler();
    if (self.print_bytecode) {
        self.getCompilingChunk().disassemble();
    }
    return !self.parser.hadError;
}

fn advance(self: *Compiler) void {
    self.parser.previous = self.parser.current;
    while (true) {
        self.parser.current = self.lexer.scanToken();
        if (self.parser.current.token_type != .ERROR) {
            break;
        }
        self.emitErrorAtCurrent(self.parser.current.asLexeme());
    }
}

fn expression(self: *Compiler) !void {
    try self.parsePrecedence(.ASSIGNMENT);
}

fn number(self: *Compiler) !void {
    const num = std.fmt.parseFloat(f64, self.parser.previous.asLexeme()) catch {
        self.emitError("Could not parse number.");
        return;
    };
    try self.emitConstant(Value{ .NUMBER = num });
}

fn emitConstant(self: *Compiler, value: Value) !void {
    try self.emitBytes(@enumToInt(OpCode.CONSTANT), try self.makeConstant(value));
}

fn makeConstant(self: *Compiler, value: Value) !u8 {
    const constant = try self.getCompilingChunk().addConstant(value);
    if (constant > @intCast(usize, std.math.maxInt(u8))) {
        self.emitError("Too many constants in one chunk.");
        return 0;
    }
    return @intCast(u8, constant);
}

fn grouping(self: *Compiler) !void {
    try self.expression();
    self.consume(.RIGHT_PARENTHESIZE, "Expect ')' after expression.");
}

fn unary(self: *Compiler) !void {
    const operator_type = self.parser.previous.token_type;
    try self.parsePrecedence(.UNARY);
    switch (operator_type) {
        .MINUS => try self.emitByte(@enumToInt(OpCode.NEGATE)),
        else => unreachable,
    }
}

fn binary(self: *Compiler) !void {
    const token_type = self.parser.previous.token_type;
    const rule = getRule(token_type);
    try self.parsePrecedence(@intToEnum(Precedence, @enumToInt(rule.precedence) + 1));
    switch (token_type) {
        .PLUS => try self.emitByte(@enumToInt(OpCode.ADD)),
        .MINUS => try self.emitByte(@enumToInt(OpCode.SUBTRACT)),
        .STAR => try self.emitByte(@enumToInt(OpCode.MULTIPLY)),
        .SLASH => try self.emitByte(@enumToInt(OpCode.DIVIDE)),
        else => unreachable,
    }
}

fn getRule(token_type: TokenType) ParseRule {
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
    if (self.parser.panicMode) {
        return;
    }
    self.parser.panicMode = true;
    std.debug.print("[line {d}]Error: ", .{token.line});
    if (token.token_type == TokenType.EOF) {
        std.debug.print(" at end", .{});
    } else if (token.token_type == TokenType.ERROR) {
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
    try self.emitByte(@enumToInt(OpCode.RETURN));
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
