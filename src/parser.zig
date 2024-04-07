const std = @import("std");
const Tokenizer = @import("./tokenizer.zig").Tokenizer;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    string: []const u8 = "",
    tokenizer: Tokenizer = undefined,
    lookahead: ?Tokenizer.Token = null,

    const Program = struct { body: []Statement };

    const NumberLiteral = struct { value: u64 };
    const StringLiteral = struct { value: []const u8 };
    const Literal = union(enum) { NumericLiteral: NumberLiteral, StringLiteral: StringLiteral };

    const Expression = union(enum) { Literal: Literal };
    const ExpressionStatement = struct { expression: Expression };
    const Statement = union(enum) { ExpressionStatement: ExpressionStatement };

    pub fn init(allocator: std.mem.Allocator) Parser {
        return Parser{ .allocator = allocator };
    }

    // Parse a string into an AST.
    pub fn parse(self: *Parser, string: []const u8) !Program {
        self.string = string;
        self.tokenizer = Tokenizer.init(self.allocator, string);

        self.lookahead = try self.tokenizer.getNextToken();

        return self.program();
    }

    // Main entry point.
    // Program
    //  : StatementList
    //  ;
    fn program(self: *Parser) !Program {
        return Program{ .body = try self.statementList() };
    }

    // StatementList
    // : Statement
    // | StatementList Statement
    // ;
    fn statementList(self: *Parser) ![]Statement {
        var _statementList = std.ArrayList(Statement).init(self.allocator);
        while (self.lookahead != null) {
            try _statementList.append(try self.statement());
        }

        return _statementList.toOwnedSlice();
    }

    // Statement
    //  : ExpressionStatement
    //  ;
    fn statement(self: *Parser) !Statement {
        return Statement{ .ExpressionStatement = try self.expressionStatement() };
    }

    // ExpressionStatement
    //  : Expression ';'
    //  ;
    fn expressionStatement(self: *Parser) !ExpressionStatement {
        const _expression = try self.expression();
        _ = try self.eat(.SemiColon);
        return ExpressionStatement{ .expression = _expression };
    }

    // Expression
    //  : Literal
    //  ;
    fn expression(self: *Parser) !Expression {
        return Expression{ .Literal = try self.literal() };
    }

    // Literal
    //  : NumericLiteral
    //  | StringLiteral
    //  ;
    fn literal(self: *Parser) !Literal {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .Number => Literal{ .NumericLiteral = try self.numericLiteral() },
                .String => Literal{ .StringLiteral = try self.stringLiteral() },
                else => error.UnexpectedToken,
            };
        }

        return error.UnexpectedEndOfInput;
    }

    // StringLiteral
    //  : String
    //  ;
    fn stringLiteral(self: *Parser) !StringLiteral {
        const token = try self.eat(.String);
        return StringLiteral{ .value = token.value[1 .. token.value.len - 1] };
    }

    // NumericLiteral
    // : Number
    // ;
    fn numericLiteral(self: *Parser) !NumberLiteral {
        const token = try self.eat(.Number);
        const number = try std.fmt.parseUnsigned(u64, token.value, 10);
        return NumberLiteral{ .value = number };
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
