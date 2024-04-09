const std = @import("std");
const Regex = @import("regex").Regex;

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    string: []const u8,
    cursor: usize,

    const MatchError = error{ RegexCompileError, RegexCapturesError };
    pub const Error = error{UnexpectedToken} || MatchError;

    pub const TokenType = enum { Number, String, SemiColon, OpenBrace, CloseBrace, OpenPran, ClosePran, AdditiveOperator, MultiplicativeOperator };
    pub const Token = struct { type: TokenType, value: []const u8 };

    const Spec = struct { re: []const u8, tokenType: ?TokenType };
    const spec = [_]Spec{ .{ .re = "^\\s", .tokenType = null }, .{ .re = "^//.*", .tokenType = null }, .{ .re = "^/\\*[\\s\\S]*?\\*/", .tokenType = null }, .{ .re = "^\\d+", .tokenType = .Number }, .{ .re = "^\"[^\"]*\"", .tokenType = .String }, .{ .re = "^'[^']*'", .tokenType = .String }, .{ .re = "^;", .tokenType = .SemiColon }, .{ .re = "^\\{", .tokenType = .OpenBrace }, .{ .re = "^\\}", .tokenType = .CloseBrace }, .{ .re = "^\\(", .tokenType = .OpenPran }, .{ .re = "^\\)", .tokenType = .ClosePran }, .{ .re = "^[+\\-]", .tokenType = .AdditiveOperator }, .{ .re = "^[\\*/]", .tokenType = .MultiplicativeOperator } };

    pub fn init(allocator: std.mem.Allocator, string: []const u8) Tokenizer {
        return Tokenizer{ .allocator = allocator, .string = string, .cursor = 0 };
    }

    fn hasMoreTokens(self: *Tokenizer) bool {
        return self.cursor < self.string.len;
    }

    pub fn getNextToken(self: *Tokenizer) Error!?Token {
        if (!self.hasMoreTokens()) {
            return null;
        }

        const string = self.string[self.cursor..];

        for (spec) |s| {
            if (try self.match(s.re, string)) |tokenValue| {
                if (s.tokenType) |tokenType| {
                    return Token{ .type = tokenType, .value = tokenValue };
                }
                return self.getNextToken();
            }
        }

        return Error.UnexpectedToken;
    }

    fn match(self: *Tokenizer, re: []const u8, string: []const u8) MatchError!?[]const u8 {
        var regex = Regex.compile(self.allocator, re) catch return MatchError.RegexCompileError;

        if (regex.captures(string) catch return MatchError.RegexCapturesError) |captures| {
            if (captures.sliceAt(0)) |matched| {
                self.cursor += matched.len;
                return matched;
            }
        }

        return null;
    }
};
