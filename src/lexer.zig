const std = @import("std");
const Token = @import("token.zig");
const TokenType = @import("token.zig").TokenType;

const Lexer = @This();
source: []const u8,
start: [*]const u8,
current: [*]const u8,
line: u32 = 1,
pub fn init(source: []const u8) Lexer {
    return Lexer{
        .source = source,
        .start = @ptrCast([*]const u8, source),
        .current = @ptrCast([*]const u8, source),
    };
}
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

inline fn peek(self: *Lexer) u8 {
    if (self.isAtEnd()) return 0 else return self.current[0];
}

fn advance(self: *Lexer) u8 {
    defer self.current += 1;
    return self.current[0];
}

fn makeToken(self: *Lexer, token_type: TokenType) Token {
    return Token{
        .token_type = token_type,
        .line = self.line,
        .length = @ptrToInt(self.current) - @ptrToInt(self.start),
        .start = self.start,
    };
}

fn makeErrorToken(self: *Lexer, message: []const u8) Token {
    return Token{
        .token_type = .TOKEN_ERROR,
        .line = self.line,
        .length = message.len,
        .start = message.ptr,
    };
}

inline fn isAtEnd(self: *Lexer) bool {
    return @ptrToInt(self.current) == @ptrToInt(&self.source[self.source.len - 1]);
}

inline fn isDigit(character: u8) bool {
    return character >= '0' and character <= '9';
}

inline fn isAlpha(character: u8) bool {
    return (character >= 'a' and character <= 'z') or
        (character >= 'A' and character <= 'Z') or
        character == '_';
}

// Why broken :( ?
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

fn identifierType(self: *Lexer) TokenType {
    switch (self.start[0]) {
        'a' => return self.checkKeyword(1, "nd", TokenType.TOKEN_AND),
        'c' => return self.checkKeyword(1, "lass", TokenType.TOKEN_CLASS),
        'e' => return self.checkKeyword(1, "lse", TokenType.TOKEN_ELSE),
        'f' => {
            if (self.distance() > 1) {
                switch (self.start[1]) {
                    'a' => return self.checkKeyword(2, "lse", TokenType.TOKEN_FALSE),
                    'o' => return self.checkKeyword(2, "r", TokenType.TOKEN_FOR),
                    'u' => return self.checkKeyword(2, "n", TokenType.TOKEN_FUN),
                    else => {},
                }
            }
        },
        'i' => return self.checkKeyword(1, "f", TokenType.TOKEN_IF),
        'n' => return self.checkKeyword(1, "ull", TokenType.TOKEN_NULL),
        'o' => return self.checkKeyword(1, "r", TokenType.TOKEN_OR),
        'p' => return self.checkKeyword(1, "rint", TokenType.TOKEN_PRINT),
        'r' => return self.checkKeyword(1, "eturn", TokenType.TOKEN_RETURN),
        's' => return self.checkKeyword(1, "uper", TokenType.TOKEN_SUPER),
        't' => {
            if (self.distance() > 1) {
                switch (self.start[1]) {
                    'h' => return self.checkKeyword(2, "is", TokenType.TOKEN_THIS),
                    'r' => return self.checkKeyword(2, "ue", TokenType.TOKEN_TRUE),
                    else => {},
                }
            }
        },
        'v' => return self.checkKeyword(1, "ar", TokenType.TOKEN_VAR),
        'w' => return self.checkKeyword(1, "hile", TokenType.TOKEN_WHILE),
        else => {},
    }
    return TokenType.TOKEN_IDENTIFIER;
}

fn identifier(self: *Lexer) Token {
    while (isAlpha(self.peek()) or isDigit(self.peek())) {
        _ = self.advance();
    }
    return self.makeToken(self.identifierType());
}

inline fn checkKeyword(self: *Lexer, startIndex: usize, rest: []const u8, tokenType: TokenType) TokenType {
    return if (self.distance() == rest.len + startIndex and
        std.mem.eql(u8, rest, self.start[startIndex..self.distance()])) tokenType else TokenType.TOKEN_IDENTIFIER;
}

inline fn distance(self: *Lexer) usize {
    return @ptrToInt(self.current) - @ptrToInt(self.start);
}

test "Scan Token" {
    var source: []const u8 = "()!=\x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_LEFT_PARENTHESIZE, token.token_type);
    try std.testing.expectEqualSlices(u8, source[0..1], token.asLexeme());
    token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_RIGHT_PARENTHESIZE, token.token_type);
    try std.testing.expectEqualSlices(u8, source[1..2], token.asLexeme());
    token = lexer.scanToken();
    std.debug.print("token: {}\n", .{token.token_type});
    try std.testing.expectEqual(TokenType.TOKEN_BANG_EQUAL, token.token_type);
    try std.testing.expectEqualSlices(u8, source[2..4], token.asLexeme());
}

test "Can handle whitespaces" {
    var source: []const u8 = " ( ) \x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_LEFT_PARENTHESIZE, token.token_type);
    try std.testing.expectEqualSlices(u8, source[1..2], token.asLexeme());
    token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_RIGHT_PARENTHESIZE, token.token_type);
    try std.testing.expectEqualSlices(u8, source[3..4], token.asLexeme());
}

test "Can handle comments" {
    var source: []const u8 = " // this is a comment\n\x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_EOF, token.token_type);
}

test "Can handle strings" {
    var source: []const u8 = "\"zen\"\x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_STRING, token.token_type);
    try std.testing.expectEqualSlices(u8, source[0..5], token.asLexeme());
}

test "Can scan Numbers" {
    var source: []const u8 = "123\x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.TOKEN_NUMBER, token.token_type);
    try std.testing.expectEqualSlices(u8, source[0..3], token.asLexeme());
}
