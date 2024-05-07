const std = @import("std");
const Regex = @import("regex.zig").Regex;

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    string: []const u8,
    cursor: usize,

    pub const Error = error{UnexpectedToken} || Regex.Error || std.mem.Allocator.Error;

    pub const TokenType = enum { Number, String, SemiColon, OpenBrace, CloseBrace, OpenPran, ClosePran, AdditiveOperator, MultiplicativeOperator, RelationalOperator, EqualityOperator, Identifier, SimpleAssign, ComplexAssign, Let, Comma, If, Else, True, False, Null, Module, Import, LogicalAnd, LogicalOr, LogicalNot, While, Do, For, Def, Return, Dot, OpenBracket, CloseBracket, Class, Extends, Super, New, This, Lambda, Switch, Case, Default };
    pub const Token = struct { type: TokenType, value: []const u8 };

    const Spec = struct { re: [:0]const u8, tokenType: ?TokenType };
    const spec = [_]Spec{ .{ .re = "\\`\\s+", .tokenType = null }, .{ .re = "\\`//.*", .tokenType = null }, .{ .re = "\\`/\\*[\\s\\S]*?\\*/", .tokenType = null }, .{ .re = "\\`,", .tokenType = .Comma }, .{ .re = "\\`\\.", .tokenType = .Dot }, .{ .re = "\\`\\blet\\b", .tokenType = .Let }, .{ .re = "\\`\\bmodule\\b", .tokenType = .Module }, .{ .re = "\\`\\bimport\\b", .tokenType = .Import }, .{ .re = "\\`\\bif\\b", .tokenType = .If }, .{ .re = "\\`\\belse\\b", .tokenType = .Else }, .{ .re = "\\`\\bwhile\\b", .tokenType = .While }, .{ .re = "\\`\\bswitch\\b", .tokenType = .Switch }, .{ .re = "\\`\\bcase\\b", .tokenType = .Case }, .{ .re = "\\`\\bdefault\\b", .tokenType = .Default }, .{ .re = "\\`\\bdo\\b", .tokenType = .Do }, .{ .re = "\\`\\bfor\\b", .tokenType = .For }, .{ .re = "\\`\\bdef\\b", .tokenType = .Def }, .{ .re = "\\`\\breturn\\b", .tokenType = .Return }, .{ .re = "\\`\\btrue\\b", .tokenType = .True }, .{ .re = "\\`\\bfalse\\b", .tokenType = .False }, .{ .re = "\\`\\bnull\\b", .tokenType = .Null }, .{ .re = "\\`\\bclass\\b", .tokenType = .Class }, .{ .re = "\\`\\bextends\\b", .tokenType = .Extends }, .{ .re = "\\`\\bsuper\\b", .tokenType = .Super }, .{ .re = "\\`\\bnew\\b", .tokenType = .New }, .{ .re = "\\`\\bthis\\b", .tokenType = .This }, .{ .re = "\\`\\blambda\\b", .tokenType = .Lambda }, .{ .re = "\\`[0-9]+", .tokenType = .Number }, .{ .re = "\\`\\w+", .tokenType = .Identifier }, .{ .re = "\\`[=!]=", .tokenType = .EqualityOperator }, .{ .re = "\\`=", .tokenType = .SimpleAssign }, .{ .re = "\\`[+\\-\\*/]=", .tokenType = .ComplexAssign }, .{ .re = "\\`\"[^\"]*\"", .tokenType = .String }, .{ .re = "\\`'[^']*'", .tokenType = .String }, .{ .re = "\\`;", .tokenType = .SemiColon }, .{ .re = "\\`\\{", .tokenType = .OpenBrace }, .{ .re = "\\`\\}", .tokenType = .CloseBrace }, .{ .re = "\\`\\(", .tokenType = .OpenPran }, .{ .re = "\\`\\)", .tokenType = .ClosePran }, .{ .re = "\\`\\[", .tokenType = .OpenBracket }, .{ .re = "\\`\\]", .tokenType = .CloseBracket }, .{ .re = "\\`[+\\-]", .tokenType = .AdditiveOperator }, .{ .re = "\\`[\\*/]", .tokenType = .MultiplicativeOperator }, .{ .re = "\\`[<>]=?", .tokenType = .RelationalOperator }, .{ .re = "\\`&&", .tokenType = .LogicalAnd }, .{ .re = "\\`\\|\\|", .tokenType = .LogicalOr }, .{ .re = "\\`!", .tokenType = .LogicalNot } };

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
        const buffer = try self.allocator.allocSentinel(u8, string.len, 0);
        @memcpy(buffer, string);

        for (spec) |s| {
            if (try self.match(s.re, buffer)) |tokenValue| {
                if (s.tokenType) |tokenType| {
                    return Token{ .type = tokenType, .value = tokenValue };
                }
                return self.getNextToken();
            }
        }

        return Error.UnexpectedToken;
    }

    fn match(self: *Tokenizer, re: [:0]const u8, string: [:0]const u8) Regex.Error!?[]const u8 {
        const regex = try Regex.init(re);
        defer regex.deinit();

        if (try regex.exec(string)) |matched| {
            self.cursor += matched.len;
            return matched;
        }

        return null;
    }
};
