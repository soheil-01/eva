const std = @import("std");
const Regex = @import("regex").Regex;

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    string: []const u8,
    cursor: usize,

    pub const TokenType = enum { Number, String, SemiColon };

    pub const Token = struct { type: TokenType, value: []const u8 };

    const Spec = struct { re: []const u8, tokenType: ?TokenType };

    const spec = [_]Spec{ .{ .re = "^\\s", .tokenType = null }, .{ .re = "^//.*", .tokenType = null }, .{ .re = "^/\\*[\\s\\S]*?\\*/", .tokenType = null }, .{ .re = "^\\d+", .tokenType = .Number }, .{ .re = "^\"[^\"]*\"", .tokenType = .String }, .{ .re = "^'[^']*'", .tokenType = .String }, .{ .re = "^;", .tokenType = .SemiColon } };

    pub fn init(allocator: std.mem.Allocator, string: []const u8) Tokenizer {
        return Tokenizer{ .allocator = allocator, .string = string, .cursor = 0 };
    }

    fn hasMoreTokens(self: *Tokenizer) bool {
        return self.cursor < self.string.len;
    }

    pub fn getNextToken(self: *Tokenizer) !?Token {
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

        return error.UnexpectedToken;
    }

    fn match(self: *Tokenizer, re: []const u8, string: []const u8) !?[]const u8 {
        var regex = try Regex.compile(self.allocator, re);

        if (try regex.captures(string)) |captures| {
            if (captures.sliceAt(0)) |matched| {
                self.cursor += matched.len;
                return matched;
            }
        }

        return null;
    }
};
