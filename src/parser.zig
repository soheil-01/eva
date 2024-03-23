const std = @import("std");
const Tokenizer = @import("./tokenizer.zig").Tokenizer;

pub const Parser = struct {
    string: []const u8 = "",
    tokenizer: Tokenizer = undefined,
    lookahead: ?Tokenizer.Token = null,

    const Program = struct { body: ASTNode };

    const NodeType = enum { NumericLiteral, StringLiteral };

    const NodeValue = union(enum) { Number: u64, String: []const u8 };

    const ASTNode = struct {
        type: NodeType,
        value: NodeValue,
    };

    // Parse a string into an AST.
    pub fn parse(self: *Parser, allocator: std.mem.Allocator, string: []const u8) !Program {
        self.string = string;
        self.tokenizer = Tokenizer.init(allocator, string);

        self.lookahead = try self.tokenizer.getNextToken();

        return self.program();
    }

    // Main entry point.
    // Program
    //  : Literal
    //  ;
    fn program(self: *Parser) !Program {
        return Program{ .body = try self.literal() };
    }

    // Literal
    //  : NumericLiteral
    //  | StringLiteral
    //  ;
    fn literal(self: *Parser) !ASTNode {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .Number => self.numericLiteral(),
                .String => self.stringLiteral(),
            };
        }

        return error.UnexpectedEndOfInput;
    }

    // StringLiteral
    //  : String
    //  ;
    fn stringLiteral(self: *Parser) !ASTNode {
        const token = try self.eat(.String);
        return ASTNode{ .type = .StringLiteral, .value = NodeValue{ .String = token.value[1 .. token.value.len - 1] } };
    }

    // NumericLiteral
    // : Number
    // ;
    fn numericLiteral(self: *Parser) !ASTNode {
        const token = try self.eat(.Number);
        const number = try std.fmt.parseUnsigned(u64, token.value, 10);
        return ASTNode{ .type = .NumericLiteral, .value = NodeValue{ .Number = number } };
    }

    fn eat(self: *Parser, tokenType: Tokenizer.TokenType) !Tokenizer.Token {
        if (self.lookahead) |token| {
            if (token.type != tokenType) {
                return error.UnexpectedToken;
            }

            self.lookahead = try self.tokenizer.getNextToken();

            return token;
        }

        return error.UnexpectedEndOfInput;
    }
};
