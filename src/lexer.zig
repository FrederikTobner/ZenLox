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
        return self.makeToken(TokenType.EOF);
    }
    const character = self.advance();
    if (isDigit(character)) {
        return self.number();
    }
    if (isAlpha(character)) {
        return self.identifier();
    }
    switch (character) {
        '(' => return self.makeToken(TokenType.LEFT_PARENTHESIZE),
        ')' => return self.makeToken(TokenType.RIGHT_PARENTHESIZE),
        '{' => return self.makeToken(TokenType.LEFT_BRACE),
        '}' => return self.makeToken(TokenType.RIGHT_BRACE),
        ',' => return self.makeToken(TokenType.COMMA),
        '.' => return self.makeToken(TokenType.DOT),
        '-' => return self.makeToken(TokenType.MINUS),
        '+' => return self.makeToken(TokenType.PLUS),
        ';' => return self.makeToken(TokenType.SEMICOLON),
        '*' => return self.makeToken(TokenType.STAR),
        '!' => return self.makeToken(if (self.match('=')) TokenType.BANG_EQUAL else TokenType.BANG),
        '=' => return self.makeToken(if (self.match('=')) TokenType.EQUAL_EQUAL else TokenType.EQUAL),
        '<' => return self.makeToken(if (self.match('=')) TokenType.LESS_EQUAL else TokenType.LESS),
        '>' => return self.makeToken(if (self.match('=')) TokenType.GREATER_EQUAL else TokenType.GREATER),
        '/' => {
            if (self.match('/')) {
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    _ = self.advance();
                }
                return self.scanToken();
            }
            return self.makeToken(TokenType.SLASH);
        },
        '"' => return self.string(),
        else => return Token{
            .tokenType = .ERROR,
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

fn makeToken(self: *Lexer, tokenType: TokenType) Token {
    return Token{
        .tokenType = tokenType,
        .line = self.line,
        .length = @ptrToInt(self.current) - @ptrToInt(self.start),
        .start = self.start,
    };
}

fn makeErrorToken(self: *Lexer, message: []const u8) Token {
    return Token{
        .tokenType = .ERROR,
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
    return self.makeToken(TokenType.STRING);
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
    return self.makeToken(TokenType.NUMBER);
}

fn identifierType(self: *Lexer) TokenType {
    switch (self.start[0]) {
        'a' => return self.checkKeyword(1, "nd", TokenType.AND),
        'c' => return self.checkKeyword(1, "lass", TokenType.CLASS),
        'e' => return self.checkKeyword(1, "lse", TokenType.ELSE),
        'f' => {
            if (self.distance() > 1) {
                switch (self.start[1]) {
                    'a' => return self.checkKeyword(2, "lse", TokenType.FALSE),
                    'o' => return self.checkKeyword(2, "r", TokenType.FOR),
                    'u' => return self.checkKeyword(2, "n", TokenType.FUN),
                    else => {},
                }
            }
        },
        'i' => return self.checkKeyword(1, "f", TokenType.IF),
        'n' => return self.checkKeyword(1, "ull", TokenType.NULL),
        'o' => return self.checkKeyword(1, "r", TokenType.OR),
        'p' => return self.checkKeyword(1, "rint", TokenType.PRINT),
        'r' => return self.checkKeyword(1, "eturn", TokenType.RETURN),
        's' => return self.checkKeyword(1, "uper", TokenType.SUPER),
        't' => {
            if (self.distance() > 1) {
                switch (self.start[1]) {
                    'h' => return self.checkKeyword(2, "is", TokenType.THIS),
                    'r' => return self.checkKeyword(2, "ue", TokenType.TRUE),
                    else => {},
                }
            }
        },
        'v' => return self.checkKeyword(1, "ar", TokenType.VAR),
        'w' => return self.checkKeyword(1, "hile", TokenType.WHILE),
        else => {},
    }
    return TokenType.IDENTIFIER;
}

fn identifier(self: *Lexer) Token {
    while (isAlpha(self.peek()) or isDigit(self.peek())) {
        _ = self.advance();
    }
    return self.makeToken(self.identifierType());
}

inline fn checkKeyword(self: *Lexer, startIndex: usize, rest: []const u8, tokenType: TokenType) TokenType {
    return if (self.distance() == rest.len + startIndex and
        std.mem.eql(u8, rest, self.start[startIndex..self.distance()])) tokenType else TokenType.IDENTIFIER;
}

inline fn distance(self: *Lexer) usize {
    return @ptrToInt(self.current) - @ptrToInt(self.start);
}

test "Scan Token" {
    var source: []const u8 = "()!=\x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.LEFT_PARENTHESIZE, token.tokenType);
    try std.testing.expectEqualSlices(u8, source[0..0], token.asLexeme());
    token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.RIGHT_PARENTHESIZE, token.tokenType);
    try std.testing.expectEqualSlices(u8, source[1..1], token.asLexeme());
    token = lexer.scanToken();
    std.debug.print("token: {}\n", .{token.tokenType});
    try std.testing.expectEqual(TokenType.BANG_EQUAL, token.tokenType);
    try std.testing.expectEqualSlices(u8, source[2..3], token.asLexeme());
}

test "Can handle whitespaces" {
    var source: []const u8 = " ( ) \x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.LEFT_PARENTHESIZE, token.tokenType);
    try std.testing.expectEqualSlices(u8, source[1..1], token.asLexeme());
    token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.RIGHT_PARENTHESIZE, token.tokenType);
    try std.testing.expectEqualSlices(u8, source[3..3], token.asLexeme());
}

test "Can handle comments" {
    var source: []const u8 = " // this is a comment\n\x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.EOF, token.tokenType);
}

test "Can handle strings" {
    var source: []const u8 = "\"zen\"\x00";
    var lexer = Lexer.init(source);
    var token = lexer.scanToken();
    try std.testing.expectEqual(TokenType.STRING, token.tokenType);
    try std.testing.expectEqualSlices(u8, source[0..4], token.asLexeme());
}
