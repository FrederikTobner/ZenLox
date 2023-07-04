const std = @import("std");

const Chunk = @import("chunk.zig");
const Lexer = @import("lexer.zig");
const Object = @import("object.zig").Object;
const ObjectFunction = @import("object.zig").ObjectFunction;
const ObjectString = @import("object.zig").ObjectString;
const OpCode = @import("chunk.zig").OpCode;
const TokenType = @import("token.zig").TokenType;
const Token = @import("token.zig");
const Value = @import("value.zig").Value;
const MemoryMutator = @import("memory_mutator.zig");
const Disassembler = @import("disassembler.zig");

const Compiler = @This();
parser: Parser,
lexer: Lexer,
print_bytecode: bool = @import("debug_options").printBytecode,
memory_mutator: *MemoryMutator = undefined,
rules: std.EnumArray(TokenType, ParseRule),
compiler_contex: CompilerContex = undefined,

const FunctionType = enum {
    TYPE_FUNCTION,
    TYPE_SCRIPT,
};

const CompilerContex = struct {
    object_function: *ObjectFunction = undefined,
    function_type: FunctionType = FunctionType.TYPE_SCRIPT,
    locals: [256]Local,
    local_count: u8 = 1,
    scope_depth: u8 = 0,
    pub fn init(function_type: FunctionType, memory_mutator: *MemoryMutator) !CompilerContex {
        var locals: [256]Local = undefined;
        return CompilerContex{
            .function_type = function_type,
            .object_function = try memory_mutator.createFunctionObject(),
            .locals = locals,
        };
    }
};
const Parser = struct {
    current: Token = undefined,
    previous: Token = undefined,
    had_error: bool = false,
    panic_mode: bool = false,
};

const Local = struct {
    name: Token = undefined,
    depth: u8 = 0,
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

pub fn init(memory_mutator: *MemoryMutator) !Compiler {
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
    rules.set(.TOKEN_AND, ParseRule{ .infix = andExpression, .precedence = .PREC_AND });
    return Compiler{
        .parser = Parser{},
        .lexer = undefined,
        .memory_mutator = memory_mutator,
        .rules = rules,
        .compiler_contex = try CompilerContex.init(FunctionType.TYPE_SCRIPT, memory_mutator),
    };
}

pub fn compile(self: *Compiler, source: []const u8) !?*ObjectFunction {
    self.lexer = Lexer.init(source);
    self.advance();
    while (!self.match(.TOKEN_EOF)) {
        try self.declaration();
    }
    var fun = try self.endCompilerContext();
    return if (self.parser.had_error) null else fun;
}

fn declaration(self: *Compiler) !void {
    if (self.match(.TOKEN_FUN)) {
        try self.funDeclaration();
    } else if (self.match(.TOKEN_VAR)) {
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

fn funDeclaration(self: *Compiler) !void {
    var global = try self.parseVariable("Expect function name.");
    try self.markInitialized();
    try self.function(FunctionType.TYPE_FUNCTION);
    try self.defineVariable(global);
}

fn markInitialized(self: *Compiler) !void {
    if (self.compiler_contex.scope_depth == 0) {
        return;
    }
    self.compiler_contex.locals[self.compiler_contex.local_count - 1].depth = self.compiler_contex.scope_depth;
}

fn function(self: *Compiler, function_type: FunctionType) !void {
    const compiler_contex = try CompilerContex.init(function_type, self.memory_mutator);
    var old_compiler_contex = self.compiler_contex;
    self.compiler_contex = compiler_contex;
    self.beginScope();
    self.consume(TokenType.TOKEN_LEFT_PARENTHESIZE, "Expect '(' after function name.");
    if (!self.check(TokenType.TOKEN_RIGHT_PARENTHESIZE)) {
        while (true) {
            self.compiler_contex.object_function.arity += 1;
            if (self.compiler_contex.object_function.arity > 255) {
                self.emitErrorAtCurrent("Can't have more than 255 parameters.");
            }
            var index = try self.parseVariable("Expect parameter name.");
            try self.defineVariable(index);
            if (!self.match(TokenType.TOKEN_COMMA)) {
                break;
            }
        }
    }
    self.consume(TokenType.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after parameters.");
    self.consume(TokenType.TOKEN_LEFT_BRACE, "Expect '{' before function body.");
    try self.block();
    var fun = try self.endCompilerContext();
    self.compiler_contex = old_compiler_contex;
    try self.emitConstant(Value{ .VAL_OBJECT = &fun.object });
}

fn call(self: *Compiler) !void {
    var arg_count: u8 = try self.argumentList();
    try self.emitOpcode(.OP_CALL);
    try self.emitByte(arg_count);
}

fn argumentList(self: *Compiler) !u8 {
    var arg_count: u8 = 0;
    if (!self.check(TokenType.TOKEN_RIGHT_PARENTHESIZE)) {
        while (true) {
            try self.expression();
            if (arg_count == 255) {
                self.emitError("Can't have more than 255 arguments.");
            }
            arg_count += 1;
            if (!self.match(TokenType.TOKEN_COMMA)) {
                break;
            }
        }
    }
    try self.consume(TokenType.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after arguments.");
    return arg_count;
}
fn parseVariable(self: *Compiler, error_message: []const u8) !u24 {
    self.consume(.TOKEN_IDENTIFIER, error_message);
    try self.declareVariable();
    if (self.compiler_contex.scope_depth > 0) {
        return 0;
    }
    return try self.identifierConstant(self.parser.previous);
}

fn defineVariable(self: *Compiler, index: u24) !void {
    if (self.compiler_contex.scope_depth > 0) {
        return;
    }
    try self.emitIndexOpcode(index, .OP_DEFINE_GLOBAL, .OP_DEFINE_GLOBAL_LONG);
}

fn declareVariable(self: *Compiler) !void {
    if (self.compiler_contex.scope_depth == 0) {
        return;
    }
    var counter = self.compiler_contex.local_count;
    while (counter > 0) {
        counter -= 1;
        var local: Local = self.compiler_contex.locals[counter];
        if (local.depth != -1 and local.depth < self.compiler_contex.scope_depth) {
            break;
        }
        if (identifiersEqual(self.parser.previous.start[0..self.parser.previous.length], local.name.start[0..local.name.length])) {
            self.emitError("Already variable with this name in this scope.");
        }
    }
    const name: Token = self.parser.previous;
    try self.addLocal(name);
}

fn identifiersEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }
    return std.mem.eql(u8, a, b);
}

fn addLocal(self: *Compiler, name: Token) !void {
    if (self.compiler_contex.local_count == std.math.maxInt(u8)) {
        self.emitError("Too many local variables in function.");
        return;
    }
    const local: Local = Local{ .name = name, .depth = self.compiler_contex.scope_depth };
    self.compiler_contex.locals[self.compiler_contex.local_count] = local;
    self.compiler_contex.local_count += 1;
}

fn identifierConstant(self: *Compiler, name: Token) !u24 {
    return @intCast(u24, try self.makeConstant(try self.memory_mutator.createStringObjectValue(name.start[0..name.length])));
}

fn statement(self: *Compiler) !void {
    if (self.match(.TOKEN_PRINT)) {
        try self.printStatement();
    } else if (self.match(.TOKEN_IF)) {
        try self.ifStatement();
    } else if (self.match(.TOKEN_WHILE)) {
        try self.whileStatement();
    } else if (self.match(.TOKEN_FOR)) {
        try self.forStatement();
    } else if (self.match(.TOKEN_LEFT_BRACE)) {
        self.beginScope();
        try self.block();
        try self.endScope();
    } else {
        try self.expressionStatement();
    }
}

fn printStatement(self: *Compiler) !void {
    try self.expression();
    self.consume(.TOKEN_SEMICOLON, "Expect ';' after value.");
    try self.emitOpcode(OpCode.OP_PRINT);
}

fn ifStatement(self: *Compiler) std.mem.Allocator.Error!void {
    self.consume(.TOKEN_LEFT_PARENTHESIZE, "Expect '(' after 'if'.");
    try self.expression();
    self.consume(.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after condition.");
    const then_jump: u16 = try self.emitJump(OpCode.OP_JUMP_IF_FALSE);
    try self.emitOpcode(.OP_POP);
    try self.statement();
    const else_jump: u16 = try self.emitJump(OpCode.OP_JUMP);
    try self.patchJump(then_jump);
    try self.emitOpcode(.OP_POP);
    if (self.match(.TOKEN_ELSE)) {
        try self.statement();
    }
    try self.patchJump(else_jump);
}

fn forStatement(self: *Compiler) std.mem.Allocator.Error!void {
    self.beginScope();
    self.consume(.TOKEN_LEFT_PARENTHESIZE, "Expect '(' after 'for'.");
    if (self.match(.TOKEN_SEMICOLON)) {
        // No initializer.
    } else if (self.match(.TOKEN_VAR)) {
        try self.varDeclaration();
    } else {
        try self.expressionStatement();
    }
    var loop_start: u16 = @intCast(u16, self.getCompilingChunk().byte_code.items.len);
    var exit_jump: i17 = -1;
    if (!self.match(.TOKEN_SEMICOLON)) {
        try self.expression();
        self.consume(.TOKEN_SEMICOLON, "Expect ';' after loop condition.");
        exit_jump = try self.emitJump(OpCode.OP_JUMP_IF_FALSE);
        try self.emitOpcode(.OP_POP);
    }
    if (!self.match(.TOKEN_RIGHT_PARENTHESIZE)) {
        const body_jump: u16 = try self.emitJump(OpCode.OP_JUMP);
        const increment_start: u16 = @intCast(u16, self.getCompilingChunk().byte_code.items.len);
        try self.expression();
        try self.emitOpcode(.OP_POP);
        self.consume(.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after for clauses.");
        try self.emitLoop(loop_start);
        loop_start = increment_start;
        try self.patchJump(body_jump);
    }
    try self.statement();
    try self.emitLoop(loop_start);
    if (exit_jump != -1) {
        try self.patchJump(@intCast(u16, exit_jump));
        try self.emitOpcode(.OP_POP);
    }
    try self.endScope();
}

fn whileStatement(self: *Compiler) std.mem.Allocator.Error!void {
    const loop_start: u16 = @intCast(u16, self.getCompilingChunk().byte_code.items.len);
    self.consume(.TOKEN_LEFT_PARENTHESIZE, "Expect '(' after 'while'.");
    try self.expression();
    self.consume(.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after condition.");
    const exit_jump: u16 = try self.emitJump(OpCode.OP_JUMP_IF_FALSE);
    try self.emitOpcode(.OP_POP);
    try self.statement();
    try self.emitLoop(loop_start);
    try self.patchJump(exit_jump);
    try self.emitOpcode(.OP_POP);
}

fn emitLoop(self: *Compiler, loop_start: u16) !void {
    try self.emitOpcode(.OP_LOOP);
    const calculated_offset: usize = self.getCompilingChunk().byte_code.items.len - @intCast(usize, loop_start) + 2;
    if (calculated_offset > std.math.maxInt(u16)) {
        self.emitError("Loop body too large.");
    }
    const offset = @intCast(u16, calculated_offset);
    const offset_bytes = [_]u8{ @intCast(u8, (offset >> 8)), @intCast(u8, offset & 0xff) };
    try self.emitBytes(offset_bytes[0..2]);
}

fn emitJump(self: *Compiler, opcode: OpCode) !u16 {
    try self.emitOpcode(opcode);
    try self.emitByte(0xff);
    try self.emitByte(0xff);
    return @intCast(u16, self.getCompilingChunk().byte_code.items.len - 2);
}

fn patchJump(self: *Compiler, offset: u16) !void {
    const jump: u16 = @intCast(u16, self.getCompilingChunk().byte_code.items.len - offset - 2);
    if (jump > std.math.maxInt(u16)) {
        self.emitError("Too much code to jump over.");
    }
    const jump_bytes = [_]u8{ @intCast(u8, (jump >> 8)), @intCast(u8, jump & 0xff) };
    try self.getCompilingChunk().byte_code.replaceRange(offset, 2, jump_bytes[0..jump_bytes.len]);
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
    var local: bool = true;
    var arg = try self.resolveLocal(name);
    if (arg == -1) {
        arg = try self.identifierConstant(name);
        local = false;
    }
    if (can_assign and self.match(.TOKEN_EQUAL)) {
        try self.expression();
        if (local) {
            try self.emitOpcode(OpCode.OP_SET_LOCAL);
            try self.emitByte(@intCast(u8, arg));
        } else {
            try self.emitIndexOpcode(@intCast(usize, arg), .OP_SET_GLOBAL, .OP_SET_GLOBAL_LONG);
        }
    } else {
        if (local) {
            try self.emitOpcode(OpCode.OP_GET_LOCAL);
            try self.emitByte(@intCast(u8, arg));
        } else {
            try self.emitIndexOpcode(@intCast(usize, arg), .OP_GET_GLOBAL, .OP_GET_GLOBAL_LONG);
        }
    }
}

fn resolveLocal(self: *Compiler, name: Token) !i64 {
    var counter = self.compiler_contex.local_count;
    while (counter > 0) {
        counter -= 1;
        var local: Local = self.compiler_contex.locals[counter];
        if (identifiersEqual(name.start[0..name.length], local.name.start[0..local.name.length])) {
            return counter;
        }
    }
    return -1;
}

fn block(self: *Compiler) std.mem.Allocator.Error!void {
    while (!self.check(.TOKEN_RIGHT_BRACE) and !self.check(.TOKEN_EOF)) {
        try self.declaration();
    }
    self.consume(.TOKEN_RIGHT_BRACE, "Expect '}' after block.");
}

fn andExpression(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const end_jump: u16 = try self.emitJump(OpCode.OP_JUMP_IF_FALSE);
    try self.emitOpcode(OpCode.OP_POP);
    try self.parsePrecedence(Precedence.PREC_AND);
    try self.patchJump(end_jump);
}

fn orExpression(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const else_jump: u16 = try self.emitJump(OpCode.OP_JUMP_IF_FALSE);
    const end_jump: u16 = try self.emitJump(OpCode.OP_JUMP);
    try self.patchJump(else_jump);
    try self.emitOpcode(OpCode.OP_POP);
    try self.parsePrecedence(Precedence.PREC_OR);
    try self.patchJump(end_jump);
}

fn beginScope(self: *Compiler) void {
    self.compiler_contex.scope_depth += 1;
}

fn endScope(self: *Compiler) !void {
    self.compiler_contex.scope_depth -= 1;
    while (self.compiler_contex.local_count > 0 and self.compiler_contex.locals[self.compiler_contex.local_count - 1].depth > self.compiler_contex.scope_depth) {
        try self.emitOpcode(OpCode.OP_POP);
        self.compiler_contex.local_count -= 1;
    }
}

fn check(self: *Compiler, token_type: TokenType) bool {
    return self.parser.current.token_type == token_type;
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
    try self.emitOpcode(.OP_RETURN);
}

inline fn endCompilerContext(self: *Compiler) !*ObjectFunction {
    try self.emitReturn();
    if (self.print_bytecode) {
        self.compiler_contex.object_function.printDebug();
        Disassembler.disassemble(self.getCompilingChunk());
    }
    return self.compiler_contex.object_function;
}

inline fn getCompilingChunk(self: *Compiler) *Chunk {
    return &self.compiler_contex.object_function.chunk;
}
