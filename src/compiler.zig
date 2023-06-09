const std = @import("std");

const Chunk = @import("chunk.zig");
const Lexer = @import("lexer.zig").Lexer;
const TokenType = @import("token.zig").TokenType;
const Token = @import("token.zig").Token;

pub const Compiler = struct {
    pub fn compile(source: []const u8, stdout: anytype) !void {
        var lexer = Lexer.init(source);
        var token: Token = lexer.scanToken();
        var currentLine: u32 = 0;
        while (token.tokenType != TokenType.EOF) : (token = lexer.scanToken()) {
            if (token.line != currentLine) {
                currentLine = token.line;
                try stdout.print("{d:4} ", .{token.line});
            } else {
                try stdout.print("   | ", .{});
            }
            const tokenStartIndex = @ptrToInt(token.start) - @ptrToInt(source.ptr);
            try stdout.print("{} '{s}'\n", .{ token.tokenType, source[tokenStartIndex .. tokenStartIndex + token.length] });
        }
    }
};
