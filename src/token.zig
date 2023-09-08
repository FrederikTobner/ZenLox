const std = @import("std");

/// The different types of tokens of the ZenLox language.
pub const TokenType = enum {
    TOKEN_AND,
    TOKEN_BANG,
    TOKEN_BANG_EQUAL,
    TOKEN_CLASS,
    TOKEN_COMMA,
    TOKEN_DOT,
    TOKEN_ELSE,
    TOKEN_EOF,
    TOKEN_EQUAL,
    TOKEN_EQUAL_EQUAL,
    TOKEN_ERROR,
    TOKEN_FALSE,
    TOKEN_FOR,
    TOKEN_FUN,
    TOKEN_GREATER,
    TOKEN_GREATER_EQUAL,
    TOKEN_IDENTIFIER,
    TOKEN_IF,
    TOKEN_LEFT_BRACE,
    TOKEN_LEFT_PARENTHESIZE,
    TOKEN_LESS,
    TOKEN_LESS_EQUAL,
    TOKEN_MINUS,
    TOKEN_NULL,
    TOKEN_NUMBER,
    TOKEN_OR,
    TOKEN_PLUS,
    TOKEN_RETURN,
    TOKEN_PRINT,
    TOKEN_RIGHT_BRACE,
    TOKEN_RIGHT_PARENTHESIZE,
    TOKEN_SEMICOLON,
    TOKEN_SLASH,
    TOKEN_STAR,
    TOKEN_STRING,
    TOKEN_SUPER,
    TOKEN_THIS,
    TOKEN_TRUE,
    TOKEN_VAR,
    TOKEN_WHILE,
};
/// A token that is produced by the lexer.
const Token = @This();
/// The type of a token.
token_type: TokenType,
/// Pointer to the start of the lexeme.
start: [*]const u8,
/// The line number of the token.
line: u32,
/// The length of the lexeme.
length: usize,

/// Initializes a token.
pub fn init(token_type: TokenType, start: [*]const u8, line: u32, length: usize) Token {
    return Token{
        .token_type = token_type,
        .start = start,
        .line = line,
        .length = length,
    };
}

/// Returns the lexeme of the token.
pub fn asLexeme(self: *Token) []const u8 {
    return self.start[0..self.length];
}

test "Token asLexeme" {
    var source: []const u8 = "123";
    var token: Token = Token.init(.TOKEN_NUMBER, @ptrCast(source), 1, 3);
    try std.testing.expectEqualSlices(u8, source[0..], token.asLexeme());
}
