const std = @import("std");
const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;

/// Performs lexical analysis on a source string.
const Lexer = @This();
source: []const u8,
start: [*]const u8,
current: [*]const u8,
line: u32 = 1,
pub fn init(source: []const u8) Lexer {
    return Lexer{
        .source = source,
        .start = @ptrCast(source),
        .current = @ptrCast(source),
    };
}
/// Scans the next token in the source string.
pub fn scanToken(self: *Lexer) Token {
    self.skipWhitespace();
    self.start = self.current;
    if (self.isAtEnd()) {
        return self.makeToken(TokenType.TOKEN_EOF);
    }
    const character = self.advance();
    if (isDigit(character)) {
        return self.number();
    }
    if (isAlpha(character)) {
        return self.identifier();
    }
    switch (character) {
        '(' => return self.makeToken(TokenType.TOKEN_LEFT_PARENTHESIZE),
        ')' => return self.makeToken(TokenType.TOKEN_RIGHT_PARENTHESIZE),
        '{' => return self.makeToken(TokenType.TOKEN_LEFT_BRACE),
        '}' => return self.makeToken(TokenType.TOKEN_RIGHT_BRACE),
        ',' => return self.makeToken(TokenType.TOKEN_COMMA),
        '.' => return self.makeToken(TokenType.TOKEN_DOT),
        '-' => return self.makeToken(TokenType.TOKEN_MINUS),
        '+' => return self.makeToken(TokenType.TOKEN_PLUS),
        ';' => return self.makeToken(TokenType.TOKEN_SEMICOLON),
        '*' => return self.makeToken(TokenType.TOKEN_STAR),
        '!' => return self.makeToken(if (self.match('=')) TokenType.TOKEN_BANG_EQUAL else TokenType.TOKEN_BANG),
        '=' => return self.makeToken(if (self.match('=')) TokenType.TOKEN_EQUAL_EQUAL else TokenType.TOKEN_EQUAL),
        '<' => return self.makeToken(if (self.match('=')) TokenType.TOKEN_LESS_EQUAL else TokenType.TOKEN_LESS),
        '>' => return self.makeToken(if (self.match('=')) TokenType.TOKEN_GREATER_EQUAL else TokenType.TOKEN_GREATER),
        '/' => {
            if (self.match('/')) {
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    _ = self.advance();
                }
                return self.scanToken();
            }
            return self.makeToken(TokenType.TOKEN_SLASH);
        },
        '"' => return self.string(),
        else => return Token{
            .token_type = .TOKEN_ERROR,
            .line = self.line,
            .start = self.current,
            .length = 0,
        },
    }
}

/// Skips all whitespace characters.
fn skipWhitespace(self: *Lexer) void {
    while (true) {
        switch (self.peek()) {
            ' ' => {},
            '\r' => {},
            '\t' => {},
            '\n' => self.line += 1,
            else => return,
        }
        _ = self.advance();
    }
}

/// Matches the current character with the expected one.
fn match(self: *Lexer, expected: u8) bool {
    if (self.isAtEnd()) {
        return false;
    }
    if (self.current[0] != expected) {
        return false;
    }
    self.current += 1;
    return true;
}

/// Returns the current character without advancing.
inline fn peek(self: *Lexer) u8 {
    if (self.isAtEnd()) return 0 else return self.current[0];
}

/// Advances to the next character and returns the previous one.
fn advance(self: *Lexer) u8 {
    defer self.current += 1;
    return self.current[0];
}

/// Creates a token with the given type.
fn makeToken(self: *Lexer, token_type: TokenType) Token {
    return Token{
        .token_type = token_type,
        .line = self.line,
        .length = @intFromPtr(self.current) - @intFromPtr(self.start),
        .start = self.start,
    };
}

/// Creates an error token with the given message.
fn makeErrorToken(self: *Lexer, message: []const u8) Token {
    return Token{
        .token_type = .TOKEN_ERROR,
        .line = self.line,
        .length = message.len,
        .start = message.ptr,
    };
}

/// Determines if the lexer has reached the end of the source string.
inline fn isAtEnd(self: *Lexer) bool {
    return @intFromPtr(self.current) == @intFromPtr(&self.source.ptr[self.source.len]);
}

/// Determines if the given character is a digit.
inline fn isDigit(character: u8) bool {
    return character >= '0' and character <= '9';
}

/// Determines if the given character is an alphabetic character.
inline fn isAlpha(character: u8) bool {
    return (character >= 'a' and character <= 'z') or
        (character >= 'A' and character <= 'Z') or
        character == '_';
}

/// Creates a string token.
fn string(self: *Lexer) Token {
    while (self.peek() != '"' and !self.isAtEnd()) : (_ = self.advance()) {
        if (self.peek() == '\n') {
            self.line += 1;
        }
    }
    if (self.isAtEnd()) {
        return self.makeErrorToken("Unterminated string.");
    }
    // Skipping the closing ".
    _ = self.advance();
    return self.makeToken(TokenType.TOKEN_STRING);
}

/// Creates an number token.
fn number(self: *Lexer) Token {
    while (isDigit(self.peek())) {
        _ = self.advance();
    }
    if (self.match('.') and isDigit(self.peek())) {
        _ = self.advance();
        while (isDigit(self.peek())) {
            _ = self.advance();
        }
    }
    return self.makeToken(TokenType.TOKEN_NUMBER);
}

/// Checks if the current token is a keyword.
/// If it is, it returns the token type of the keyword.
/// Otherwise, it returns `TOKEN_IDENTIFIER`.
fn identifierType(self: *Lexer) TokenType {
    switch (self.start[0]) {
        'a' => return self.checkKeyword(1, "nd", .TOKEN_AND),
        'c' => return self.checkKeyword(1, "lass", .TOKEN_CLASS),
        'e' => return self.checkKeyword(1, "lse", .TOKEN_ELSE),
        'f' => {
            if (self.distance() > 1) {
                switch (self.start[1]) {
                    'a' => return self.checkKeyword(2, "lse", .TOKEN_FALSE),
                    'o' => return self.checkKeyword(2, "r", .TOKEN_FOR),
                    'u' => return self.checkKeyword(2, "n", .TOKEN_FUN),
                    else => {},
                }
            }
        },
        'i' => return self.checkKeyword(1, "f", .TOKEN_IF),
        'n' => return self.checkKeyword(1, "ull", .TOKEN_NULL),
        'o' => return self.checkKeyword(1, "r", .TOKEN_OR),
        'p' => return self.checkKeyword(1, "rint", .TOKEN_PRINT),
        'r' => return self.checkKeyword(1, "eturn", .TOKEN_RETURN),
        's' => return self.checkKeyword(1, "uper", .TOKEN_SUPER),
        't' => {
            if (self.distance() > 1) {
                switch (self.start[1]) {
                    'h' => return self.checkKeyword(2, "is", .TOKEN_THIS),
                    'r' => return self.checkKeyword(2, "ue", .TOKEN_TRUE),
                    else => {},
                }
            }
        },
        'v' => return self.checkKeyword(1, "ar", .TOKEN_VAR),
        'w' => return self.checkKeyword(1, "hile", .TOKEN_WHILE),
        else => {},
    }
    return .TOKEN_IDENTIFIER;
}

/// Creates an identifier token.
fn identifier(self: *Lexer) Token {
    while (isAlpha(self.peek()) or isDigit(self.peek())) {
        _ = self.advance();
    }
    return self.makeToken(self.identifierType());
}

/// Checks if the current token is a keyword and returns a token of the given type if it is.
/// Otherwise, it returns a token of type `TOKEN_IDENTIFIER`.
inline fn checkKeyword(self: *Lexer, startIndex: usize, rest: []const u8, tokenType: TokenType) TokenType {
    return if (self.distance() == rest.len + startIndex and
        std.mem.eql(u8, rest, self.start[startIndex..self.distance()])) tokenType else TokenType.TOKEN_IDENTIFIER;
}

/// Calculates the distance between the start of the current token and the start of the source string.
inline fn distance(self: *Lexer) usize {
    return @intFromPtr(self.current) - @intFromPtr(self.start);
}

// Tests

fn expectTokenEquality(token: *Token, expectedLexeme: []const u8, expectedTokenType: TokenType) !void {
    try std.testing.expectEqual(expectedTokenType, token.token_type);
    try std.testing.expectEqualSlices(u8, expectedLexeme, token.asLexeme());
}

test "Scan Token" {
    var source: []const u8 = "()!=\x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try expectTokenEquality(&token, source[0..1], .TOKEN_LEFT_PARENTHESIZE);
    token = lexer.scanToken();
    try expectTokenEquality(&token, source[1..2], .TOKEN_RIGHT_PARENTHESIZE);
    token = lexer.scanToken();
    try expectTokenEquality(&token, source[2..4], .TOKEN_BANG_EQUAL);
}

test "Can handle whitespaces" {
    var source: []const u8 = " ( ) ";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try expectTokenEquality(&token, source[1..2], .TOKEN_LEFT_PARENTHESIZE);
    token = lexer.scanToken();
    try expectTokenEquality(&token, source[3..4], .TOKEN_RIGHT_PARENTHESIZE);
}

test "Can handle comments" {
    var source: []const u8 = " // this is a comment\n";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_EOF, token.token_type);
}

test "Can handle strings" {
    var source: []const u8 = "\"zen\"";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try expectTokenEquality(&token, source[0..5], .TOKEN_STRING);
}

test "Can scan Numbers" {
    var source: []const u8 = "123";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try expectTokenEquality(&token, source[0..3], .TOKEN_NUMBER);
}

test "Can handle identifiers" {
    var source: []const u8 = "x y";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try expectTokenEquality(&token, source[0..1], .TOKEN_IDENTIFIER);
    token = lexer.scanToken();
    try expectTokenEquality(&token, source[2..3], .TOKEN_IDENTIFIER);
}
