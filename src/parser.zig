const std = @import("std");
const Tokenizer = @import("./tokenizer.zig").Tokenizer;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    string: []const u8 = "",
    tokenizer: Tokenizer = undefined,
    lookahead: ?Tokenizer.Token = null,

    pub fn init(allocator: std.mem.Allocator) Parser {
        return Parser{ .allocator = allocator };
    }

    pub const Error = error{ UnexpectedToken, UnexpectedEndOfInput };

    // Parse a string into an AST.
    pub fn parse(self: *Parser, string: []const u8) !Program {
        self.string = string;
        self.tokenizer = Tokenizer.init(self.allocator, string);

        self.lookahead = try self.tokenizer.getNextToken();

        return self.program();
    }

    const Program = struct { body: []Statement };

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
    fn statementList(self: *Parser, stopLookahead: ?Tokenizer.TokenType) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError || std.mem.Allocator.Error)![]Statement {
        var _statementList = std.ArrayList(Statement).init(self.allocator);
        while (self.lookahead) |lookahead| {
            if (lookahead.type == stopLookahead) {
                break;
            }
            try _statementList.append(try self.statement());
        }

        return _statementList.toOwnedSlice();
    }

    const Statement = union(enum) { ExpressionStatement: ExpressionStatement, BlockStatement: BlockStatement, EmptyStatement: EmptyStatement };

    // Statement
    //  : ExpressionStatement
    //  | BlockStatement
    //  | EmptyStatement
    //  ;
    fn statement(self: *Parser) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError || std.mem.Allocator.Error)!Statement {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .OpenBrace => Statement{ .BlockStatement = try self.blockStatement() },
                .SemiColon => Statement{ .EmptyStatement = try self.emptyStatement() },
                else => Statement{ .ExpressionStatement = try self.expressionStatement() },
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    const EmptyStatement = struct {};

    // EmptyStatement
    // : ';'
    // ;
    fn emptyStatement(self: *Parser) (Error || Tokenizer.Error)!EmptyStatement {
        _ = try self.eat(.SemiColon);
        return EmptyStatement{};
    }

    const BlockStatement = struct { body: []Statement };

    // BlockStatement
    // '{' OptStatementList '}'
    // ;
    fn blockStatement(self: *Parser) (Error || Tokenizer.Error || std.fmt.ParseIntError || std.mem.Allocator.Error)!BlockStatement {
        _ = try self.eat(.OpenBrace);
        const body = try self.statementList(.CloseBrace);
        _ = try self.eat(.CloseBrace);

        return BlockStatement{ .body = body };
    }

    const ExpressionStatement = struct { expression: Expression };

    // ExpressionStatement
    //  : Expression ';'
    //  ;
    fn expressionStatement(self: *Parser) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError)!ExpressionStatement {
        const _expression = try self.expression();
        _ = try self.eat(.SemiColon);
        return ExpressionStatement{ .expression = _expression };
    }

    const Expression = union(enum) { PrimaryExpression: PrimaryExpression, BinaryExpression: BinaryExpression };

    // Expression
    //  : AdditiveExpression
    //  ;
    fn expression(self: *Parser) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError)!Expression {
        return self.additiveExpression();
    }

    const BinaryExpression = struct { operator: Tokenizer.Token, left: *Expression, right: *Expression };

    // AdditiveExpression
    //  : MultiplicativeExpression
    //  | AdditiveExpression ADDITIVE_OPERATOR MultiplicativeExpression
    //  ;
    fn additiveExpression(self: *Parser) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError)!Expression {
        return self.binaryExpression(multiplicativeExpression, .AdditiveOperator);
    }

    // MultiplicativeExpression
    //  : PrimaryExpression
    //  | MultiplicativeExpression MULTIPLICATIVE_OPERATOR PrimaryExpression
    //  ;
    fn multiplicativeExpression(self: *Parser) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError)!Expression {
        return self.binaryExpression(primaryExpression, .MultiplicativeOperator);
    }

    // Generic Binary Expression
    fn binaryExpression(self: *Parser, comptime builderName: fn (*Parser) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError)!Expression, comptime operatorType: Tokenizer.TokenType) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError)!Expression {
        var left = try builderName(self);
        while (self.lookahead) |lookahead| {
            if (lookahead.type != operatorType) break;
            const operator = try self.eat(operatorType);
            var right = try builderName(self);
            var binaryE = BinaryExpression{ .left = try self.allocator.create(Expression), .right = try self.allocator.create(Expression), .operator = operator };
            binaryE.left.* = left;
            binaryE.right.* = right;
            left = Expression{ .BinaryExpression = binaryE };
        }

        return left;
    }

    const PrimaryExpression = union(enum) { Literal: Literal };

    // PrimaryExpression
    //  : Literal
    //  | ParenthesizedExpression
    //  ;
    fn primaryExpression(self: *Parser) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError)!Expression {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .OpenPran => self.parenthesizedExpression(),
                else => Expression{ .PrimaryExpression = PrimaryExpression{ .Literal = try self.literal() } },
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    // ParenthesizedExpression
    //  : '(' Expression ')'
    //  ;
    fn parenthesizedExpression(self: *Parser) (Error || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError)!Expression {
        _ = try self.eat(.OpenPran);
        const expr = try self.expression();
        _ = try self.eat(.ClosePran);
        return expr;
    }

    const Literal = union(enum) { NumericLiteral: NumberLiteral, StringLiteral: StringLiteral };

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

    const StringLiteral = struct { value: []const u8 };

    // StringLiteral
    //  : String
    //  ;
    fn stringLiteral(self: *Parser) (Error || Tokenizer.Error)!StringLiteral {
        const token = try self.eat(.String);
        return StringLiteral{ .value = token.value[1 .. token.value.len - 1] };
    }

    const NumberLiteral = struct { value: u64 };

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
