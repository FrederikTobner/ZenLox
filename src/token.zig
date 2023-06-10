const std = @import("std");

pub const TokenType = enum {
    AND,
    BANG,
    BANG_EQUAL,
    CLASS,
    COMMA,
    DOT,
    ELSE,
    EOF,
    EQUAL,
    EQUAL_EQUAL,
    ERROR,
    FALSE,
    FOR,
    FUN,
    GREATER,
    GREATER_EQUAL,
    IDENTIFIER,
    IF,
    LEFT_BRACE,
    LEFT_PARENTHESIZE,
    LESS,
    LESS_EQUAL,
    MINUS,
    NULL,
    NUMBER,
    OR,
    PLUS,
    RETURN,
    PRINT,
    RIGHT_BRACE,
    RIGHT_PARENTHESIZE,
    SEMICOLON,
    SLASH,
    STAR,
    STRING,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,
};

const Token = @This();
token_type: TokenType,
start: [*]const u8,
line: u32,
length: usize,
pub fn init(token_type: TokenType, start: [*]const u8, line: u32, length: usize) Token {
    return Token{
        .token_type = token_type,
        .start = start,
        .line = line,
        .length = length,
    };
}

pub fn asLexeme(self: *Token) []const u8 {
    return self.start[0..self.length];
}

test "Token asLexeme" {
    var source: []const u8 = "123456";
    var token = Token.init(TokenType.NUMBER, @ptrCast([*]const u8, source), 1, 3);
    try std.testing.expectEqualSlices(u8, source[0..3], token.asLexeme());
}
