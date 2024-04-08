const std = @import("std");
const Tokenizer = @import("./tokenizer.zig").Tokenizer;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    string: []const u8 = "",
    tokenizer: Tokenizer = undefined,
    lookahead: ?Tokenizer.Token = null,

    pub const Error = error{ UnexpectedToken, UnexpectedEndOfInput };

    const Program = struct { body: []Statement };

    const NumberLiteral = struct { value: u64 };
    const StringLiteral = struct { value: []const u8 };
    const Literal = union(enum) { NumericLiteral: NumberLiteral, StringLiteral: StringLiteral };

    const Expression = union(enum) { Literal: Literal };
    const ExpressionStatement = struct { expression: Expression };
    const BlockStatement = struct { body: []Statement };
    const EmptyStatement = struct {};
    const Statement = union(enum) { ExpressionStatement: ExpressionStatement, BlockStatement: BlockStatement, EmptyStatement: EmptyStatement };

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
        return Program{ .body = try self.statementList(null) };
    }

    // StatementList
    // : Statement
    // | StatementList Statement
    // ;
    fn statementList(self: *Parser, stopLookahead: ?Tokenizer.TokenType) (Error || Tokenizer.Error || std.fmt.ParseIntError || std.mem.Allocator.Error)![]Statement {
        var _statementList = std.ArrayList(Statement).init(self.allocator);
        while (self.lookahead) |lookahead| {
            if (lookahead.type == stopLookahead) {
                break;
            }
            try _statementList.append(try self.statement());
        }

        return _statementList.toOwnedSlice();
    }

    // Statement
    //  : ExpressionStatement
    //  | BlockStatement
    //  | EmptyStatement
    //  ;
    fn statement(self: *Parser) (Error || Tokenizer.Error || std.fmt.ParseIntError || std.mem.Allocator.Error)!Statement {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .OpenBrace => Statement{ .BlockStatement = try self.blockStatement() },
                .SemiColon => Statement{ .EmptyStatement = try self.emptyStatement() },
                else => Statement{ .ExpressionStatement = try self.expressionStatement() },
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    // EmptyStatement
    // : ';'
    // ;
    fn emptyStatement(self: *Parser) (Error || Tokenizer.Error)!EmptyStatement {
        _ = try self.eat(.SemiColon);
        return EmptyStatement{};
    }

    // BlockStatement
    // '{' OptStatementList '}'
    // ;
    fn blockStatement(self: *Parser) (Error || Tokenizer.Error || std.fmt.ParseIntError || std.mem.Allocator.Error)!BlockStatement {
        _ = try self.eat(.OpenBrace);
        const body = try self.statementList(.CloseBrace);
        _ = try self.eat(.CloseBrace);

        return BlockStatement{ .body = body };
    }

    // ExpressionStatement
    //  : Expression ';'
    //  ;
    fn expressionStatement(self: *Parser) (Error || Tokenizer.Error || std.fmt.ParseIntError)!ExpressionStatement {
        const _expression = try self.expression();
        _ = try self.eat(.SemiColon);
        return ExpressionStatement{ .expression = _expression };
    }

    // Expression
    //  : Literal
    //  ;
    fn expression(self: *Parser) (Error || Tokenizer.Error || std.fmt.ParseIntError)!Expression {
        return Expression{ .Literal = try self.literal() };
    }

    // Literal
    //  : NumericLiteral
    //  | StringLiteral
    //  ;
    fn literal(self: *Parser) (Error || Tokenizer.Error || std.fmt.ParseIntError)!Literal {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .Number => Literal{ .NumericLiteral = try self.numericLiteral() },
                .String => Literal{ .StringLiteral = try self.stringLiteral() },
                else => Error.UnexpectedToken,
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    // StringLiteral
    //  : String
    //  ;
    fn stringLiteral(self: *Parser) (Error || Tokenizer.Error)!StringLiteral {
        const token = try self.eat(.String);
        return StringLiteral{ .value = token.value[1 .. token.value.len - 1] };
    }

    // NumericLiteral
    // : Number
    // ;
    fn numericLiteral(self: *Parser) (Error || Tokenizer.Error || std.fmt.ParseIntError)!NumberLiteral {
        const token = try self.eat(.Number);
        const number = try std.fmt.parseUnsigned(u64, token.value, 10);
        return NumberLiteral{ .value = number };
    }

    fn eat(self: *Parser, tokenType: Tokenizer.TokenType) (Error || Tokenizer.Error)!Tokenizer.Token {
        if (self.lookahead) |token| {
            if (token.type != tokenType) {
                return Error.UnexpectedToken;
            }

            self.lookahead = try self.tokenizer.getNextToken();
            return token;
        }

        return Error.UnexpectedEndOfInput;
    }
};
