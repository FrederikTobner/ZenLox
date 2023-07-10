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
/// The parser used by the compiler
parser: Parser,
/// The lexer used by the compiler
lexer: Lexer,
/// Boolean indicating whether the printed bytecode should be printed
print_bytecode: bool = @import("debug_options").printBytecode,
/// The memory mutator used by the compiler
memory_mutator: *MemoryMutator = undefined,
/// The rules used by the compiler
rules: std.EnumArray(TokenType, ParseRule),
/// The current compiler context
compiler_contex: CompilerContex = undefined,

/// The different types of functions
const FunctionType = enum {
    /// A function declared in a script
    TYPE_FUNCTION,
    /// A script
    TYPE_SCRIPT,
};

/// Models a compiler context
const CompilerContex = struct {
    /// The function that is currently being compiled
    object_function: *ObjectFunction = undefined,
    /// The type of the function that is currently being compiled
    function_type: FunctionType = FunctionType.TYPE_SCRIPT,
    /// The local variables in the current scope
    locals: [256]Local = undefined,
    /// The number of local variables in the current scope
    local_count: u8 = 1,
    /// The depth of the current scope
    scope_depth: u7 = 0,
    /// Creates a new compiler context.
    pub fn init(function_type: FunctionType, memory_mutator: *MemoryMutator, function_name: []const u8) !CompilerContex {
        return CompilerContex{
            .function_type = function_type,
            .object_function = try memory_mutator.createFunctionObject(function_name),
        };
    }
};

/// The parser used by the compiler
const Parser = struct {
    current: Token = undefined,
    previous: Token = undefined,
    had_error: bool = false,
    panic_mode: bool = false,
};

/// Models a local variable in a scope
const Local = struct {
    name: Token = undefined,
    depth: i8 = 0,
};

/// The precedence of a parsing rule
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

/// Models a parsing rule
const ParseRule = struct {
    /// The prefix function
    prefix: ?*const fn (*Compiler, bool) std.mem.Allocator.Error!void = null,
    /// The infix function
    infix: ?*const fn (*Compiler, bool) std.mem.Allocator.Error!void = null,
    /// The precedence of the rule
    precedence: Precedence = Precedence.PREC_NONE,
};

/// Initializes the compiler.
pub fn init(memory_mutator: *MemoryMutator) !Compiler {
    var rules = std.EnumArray(TokenType, ParseRule).initFill(ParseRule{});
    rules.set(.TOKEN_LEFT_PARENTHESIZE, ParseRule{ .prefix = grouping, .infix = call, .precedence = .PREC_CALL });
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
    rules.set(.TOKEN_EQUAL, ParseRule{ .precedence = .PREC_ASSIGNMENT });
    return Compiler{
        .parser = Parser{},
        .lexer = undefined,
        .memory_mutator = memory_mutator,
        .rules = rules,
        .compiler_contex = try CompilerContex.init(FunctionType.TYPE_SCRIPT, memory_mutator, ""),
    };
}

/// Compiles the given source code into a function.
pub fn compile(self: *Compiler, source: []const u8) !?*ObjectFunction {
    self.lexer = Lexer.init(source);
    self.advance();
    while (!self.match(.TOKEN_EOF)) {
        try self.declaration();
    }
    var fun = try self.endCompilerContext();
    return if (self.parser.had_error) null else fun;
}

/// Compiles a declaration
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

/// Compiles a variable declaration
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

/// Compiles a function declaration
fn funDeclaration(self: *Compiler) !void {
    var global = try self.parseVariable("Expect function name.");
    try self.markInitialized();
    try self.function(FunctionType.TYPE_FUNCTION);
    try self.defineVariable(global);
}

/// Marks a variable that already has been declared as initialized
/// This only applies to local variables
fn markInitialized(self: *Compiler) !void {
    if (self.compiler_contex.scope_depth == 0) {
        return;
    }
    self.compiler_contex.locals[self.compiler_contex.local_count - 1].depth = self.compiler_contex.scope_depth;
}

/// Compiles a function
fn function(self: *Compiler, function_type: FunctionType) !void {
    var compiler_contex = try CompilerContex.init(function_type, self.memory_mutator, self.parser.previous.asLexeme());
    compiler_contex.scope_depth = self.compiler_contex.scope_depth;
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

fn call(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    var arg_count: u8 = try self.argumentList();
    try self.emitOpcode(.OP_CALL);
    try self.emitByte(arg_count);
}

/// Compiles a list of arguments
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
    self.consume(TokenType.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after arguments.");
    return arg_count;
}

/// Parses a variable and returns its index in the constant table.
fn parseVariable(self: *Compiler, comptime error_message: []const u8) !u24 {
    self.consume(.TOKEN_IDENTIFIER, error_message);
    try self.declareVariable();
    if (self.compiler_contex.scope_depth > 0) {
        return 0;
    }
    return try self.identifierConstant(self.parser.previous);
}

/// Defines a variable in the current scope.
fn defineVariable(self: *Compiler, index: u24) !void {
    if (self.compiler_contex.scope_depth > 0) {
        try self.markInitialized();
        return;
    }
    try self.emitIndexOpcode(index, .OP_DEFINE_GLOBAL, .OP_DEFINE_GLOBAL_LONG);
}

/// Declares a variable in the current scope.
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

/// Checks if two identifiers are equal.
fn identifiersEqual(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }
    return std.mem.eql(u8, a, b);
}

/// Addsa local variable to the current scope.
fn addLocal(self: *Compiler, name: Token) !void {
    if (self.compiler_contex.local_count == std.math.maxInt(u8)) {
        self.emitError("Too many local variables in function.");
        return;
    }
    const local: Local = Local{ .name = name, .depth = -1 };
    self.compiler_contex.locals[self.compiler_contex.local_count] = local;
    self.compiler_contex.local_count += 1;
}

/// Creates a constant from a token and returns the index of the constant in the current chunk.
fn identifierConstant(self: *Compiler, name: Token) !u24 {
    return @intCast(u24, try self.makeConstant(try self.memory_mutator.createStringObjectValue(name.start[0..name.length])));
}

/// Compiles a statement.
fn statement(self: *Compiler) !void {
    if (self.match(.TOKEN_PRINT)) {
        try self.printStatement();
    } else if (self.match(.TOKEN_IF)) {
        try self.ifStatement();
    } else if (self.match(.TOKEN_RETURN)) {
        try self.returnStatement();
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

/// Compiles a print statement.
fn printStatement(self: *Compiler) !void {
    try self.expression();
    self.consume(.TOKEN_SEMICOLON, "Expect ';' after value.");
    try self.emitOpcode(OpCode.OP_PRINT);
}

/// Compiles an if statement.
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

/// Compiles a return statement.
fn returnStatement(self: *Compiler) !void {
    if (self.compiler_contex.function_type == .TYPE_SCRIPT) {
        self.emitError("Can't return from top-level code.");
    }
    if (self.match(.TOKEN_SEMICOLON)) {
        try self.emitReturn();
    } else {
        try self.expression();
        self.consume(.TOKEN_SEMICOLON, "Expect ';' after return value.");
        try self.emitOpcode(.OP_RETURN);
    }
}

/// Compiles a for loop.
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

/// Coompiles a while statement.
fn whileStatement(self: *Compiler) std.mem.Allocator.Error!void {
    const loop_start: u16 = @intCast(u16, self.getCompilingChunk().byte_code.items.len);
    self.consume(.TOKEN_LEFT_PARENTHESIZE, "Expect '(' after 'while'.");
    try self.expression();
    self.consume(.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after condition.");
    const exit_jump: u16 = try self.emitJump(OpCode.OP_JUMP_IF_FALSE);
    try self.statement();
    try self.emitLoop(loop_start);
    try self.patchJump(exit_jump);
    try self.emitOpcode(.OP_POP);
}

/// Emits a loop instruction and returns the offset of the jump's operand.
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

/// Emits a jump instruction with the given opcode and returns the offset of the jump's operand.
fn emitJump(self: *Compiler, opcode: OpCode) !u16 {
    try self.emitOpcode(opcode);
    try self.emitByte(0xff);
    try self.emitByte(0xff);
    return @intCast(u16, self.getCompilingChunk().byte_code.items.len - 2);
}

/// Patches a jump instruction at the given offset.
fn patchJump(self: *Compiler, offset: u16) !void {
    const jump: u16 = @intCast(u16, self.getCompilingChunk().byte_code.items.len - offset - 2);
    if (jump > std.math.maxInt(u16)) {
        self.emitError("Too much code to jump over.");
    }
    const jump_bytes = [_]u8{ @intCast(u8, (jump >> 8)), @intCast(u8, jump & 0xff) };
    try self.getCompilingChunk().byte_code.replaceRange(offset, 2, jump_bytes[0..]);
}

/// Compiles an expression statement.
fn expressionStatement(self: *Compiler) !void {
    try self.expression();
    self.consume(.TOKEN_SEMICOLON, "Expect ';' after expression.");
    try self.emitOpcode(.OP_POP);
}

/// Compiles a variable reference.
fn variable(self: *Compiler, can_assign: bool) !void {
    try self.namedVariable(self.parser.previous, can_assign);
}

/// Compiles a named variable reference.
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

/// Resolves a local variable.
fn resolveLocal(self: *Compiler, name: Token) !i64 {
    var counter = self.compiler_contex.local_count;
    while (counter > 0) : (counter -= 1) {
        var local: Local = self.compiler_contex.locals[counter];
        if (identifiersEqual(name.start[0..name.length], local.name.start[0..local.name.length])) {
            return counter;
        }
    }
    return -1;
}

/// Compiles a block statement.
fn block(self: *Compiler) std.mem.Allocator.Error!void {
    while (!self.check(.TOKEN_RIGHT_BRACE) and !self.check(.TOKEN_EOF)) {
        try self.declaration();
    }
    self.consume(.TOKEN_RIGHT_BRACE, "Expect '}' after block.");
}

/// Compiles an and expression.
fn andExpression(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const end_jump: u16 = try self.emitJump(OpCode.OP_JUMP_IF_FALSE);
    try self.emitOpcode(OpCode.OP_POP);
    try self.parsePrecedence(Precedence.PREC_AND);
    try self.patchJump(end_jump);
}

/// Compiles an or expression.
fn orExpression(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const else_jump: u16 = try self.emitJump(OpCode.OP_JUMP_IF_FALSE);
    const end_jump: u16 = try self.emitJump(OpCode.OP_JUMP);
    try self.patchJump(else_jump);
    try self.emitOpcode(OpCode.OP_POP);
    try self.parsePrecedence(Precedence.PREC_OR);
    try self.patchJump(end_jump);
}

/// Begins a new scope.
fn beginScope(self: *Compiler) void {
    self.compiler_contex.scope_depth += 1;
}

/// Ends the current scope and emits the necessary opcodes to remove the local variables declared in that scope.
fn endScope(self: *Compiler) !void {
    self.compiler_contex.scope_depth -= 1;
    while (self.compiler_contex.local_count > 0 and self.compiler_contex.locals[self.compiler_contex.local_count - 1].depth > self.compiler_contex.scope_depth) {
        try self.emitOpcode(OpCode.OP_POP);
        self.compiler_contex.local_count -= 1;
    }
}

/// Checks if the current token is of the given type.
fn check(self: *Compiler, token_type: TokenType) bool {
    return self.parser.current.token_type == token_type;
}

/// Synchronizes the parser after a syntax error.
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

/// Advances the parser to the next token.
fn advance(self: *Compiler) void {
    self.parser.previous = self.parser.current;
    while (true) {
        self.parser.current = self.lexer.scanToken();
        if (self.parser.current.token_type != .TOKEN_ERROR) {
            break;
        }
        self.emitErrorAtCurrent("Invalid token.");
    }
}

/// Compiles a expression.
fn expression(self: *Compiler) !void {
    try self.parsePrecedence(.PREC_ASSIGNMENT);
}

/// Compiles a numeric literal.
fn number(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const num = std.fmt.parseFloat(f64, self.parser.previous.asLexeme()) catch {
        self.emitError("Could not parse number.");
        return;
    };
    try self.emitConstant(Value{ .VAL_NUMBER = num });
}

/// Compiles a literal expression.
fn literal(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    switch (self.parser.previous.token_type) {
        .TOKEN_FALSE => try self.emitOpcode(.OP_FALSE),
        .TOKEN_NULL => try self.emitOpcode(.OP_NULL),
        .TOKEN_TRUE => try self.emitOpcode(.OP_TRUE),
        else => unreachable,
    }
}

/// Compiles a string literal.
fn string(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    const lexeme = self.parser.previous.asLexeme();
    try self.emitConstant(try self.memory_mutator.createStringObjectValue(lexeme[1 .. lexeme.len - 1]));
}

/// Emits a constant instruction and its index in the current chunk.
fn emitConstant(self: *Compiler, value: Value) !void {
    const index = try self.makeConstant(value);
    try self.emitIndexOpcode(index, .OP_CONSTANT, .OP_CONSTANT_LONG);
}

/// Creates a constant in the current chunk and returns its index.
inline fn makeConstant(self: *Compiler, value: Value) !usize {
    return @intCast(u24, try self.getCompilingChunk().addConstant(value));
}

/// Compiles a grouping expression.
fn grouping(self: *Compiler, can_assign: bool) !void {
    _ = can_assign;
    try self.expression();
    self.consume(.TOKEN_RIGHT_PARENTHESIZE, "Expect ')' after expression.");
}

/// Compiles a unary operator.
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

/// Compiles a binary operator.
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

/// Returns the parsing rule for the given token type
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

/// Consumes the current token if it matches the given type, otherwise emits an error.
fn consume(self: *Compiler, token_type: TokenType, comptime message: []const u8) void {
    if (self.parser.current.token_type == token_type) {
        self.advance();
        return;
    }
    self.emitErrorAtCurrent(message);
}

/// Matches the current token with the given type and advances the parser if it matches.
fn match(self: *Compiler, token_type: TokenType) bool {
    if (self.parser.current.token_type != token_type) {
        return false;
    }
    self.advance();
    return true;
}

/// Emits an error at the current token.
inline fn emitError(self: *Compiler, comptime message: []const u8) void {
    self.emitErrorAtCurrent(message);
}

/// Emits an error at the current token.
inline fn emitErrorAtCurrent(self: *Compiler, comptime message: []const u8) void {
    self.emitErrorAt(&self.parser.previous, message);
}

/// Emits an error at the given token.
fn emitErrorAt(self: *Compiler, token: *Token, comptime message: []const u8) void {
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

/// Emits the given byte to the current chunk.
inline fn emitByte(self: *Compiler, byte: u8) !void {
    try self.getCompilingChunk().writeByte(byte, self.parser.previous.line);
}

/// Emits the given bytes to the current chunk.
fn emitBytes(self: *Compiler, bytes: []const u8) !void {
    for (bytes) |byte| {
        try self.emitByte(byte);
    }
}

/// Emits an index opcode. If the index is greater than the max u8, it will emit the long opcode.
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

/// Emits the given opcode.
inline fn emitOpcode(self: *Compiler, comptime op_code: OpCode) !void {
    try self.emitByte(@enumToInt(op_code));
}

/// Emits the given opcodes.
fn emitOpcodes(self: *Compiler, comptime op_codes: []const OpCode) !void {
    for (op_codes) |op_code| {
        try self.emitByte(@enumToInt(op_code));
    }
}

/// Emits a return opcode.
inline fn emitReturn(self: *Compiler) !void {
    try self.emitOpcode(.OP_RETURN);
}

/// Ends the current compiler context and returns the compiled function.
inline fn endCompilerContext(self: *Compiler) !*ObjectFunction {
    try self.emitReturn();
    if (self.print_bytecode) {
        self.compiler_contex.object_function.printDebug();
        Disassembler.disassemble(self.getCompilingChunk());
    }
    return self.compiler_contex.object_function;
}

/// Returns the current compiling chunk.
inline fn getCompilingChunk(self: *Compiler) *Chunk {
    return &self.compiler_contex.object_function.chunk;
}
