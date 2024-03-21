const std = @import("std");

pub const Tokenizer = struct {
    allocator: std.mem.Allocator,
    string: []const u8,
    cursor: usize,

    pub const TokenType = enum { Number, String };

    pub const Token = struct { type: TokenType, value: []const u8 };

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

        if (std.ascii.isDigit(self.string[self.cursor])) {
            var number = std.ArrayList(u8).init(self.allocator);

            while (self.hasMoreTokens() and std.ascii.isDigit(self.string[self.cursor])) : (self.cursor += 1) {
                try number.append(self.string[self.cursor]);
            }

            const value = try number.toOwnedSlice();

            return Token{ .type = .Number, .value = value };
        }

        if (self.string[self.cursor] == '"') {
            var s = std.ArrayList(u8).init(self.allocator);

            try s.append(self.string[self.cursor]);
            self.cursor += 1;

            while (self.hasMoreTokens() and self.string[self.cursor] != '"') : (self.cursor += 1) {
                try s.append(self.string[self.cursor]);
            }

            try s.append(self.string[self.cursor]);
            self.cursor += 1;

            const value = try s.toOwnedSlice();

            return Token{ .type = .String, .value = value };
        }

        return null;
    }
};
