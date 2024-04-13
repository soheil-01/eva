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

    pub const Error = error{ UnexpectedToken, UnexpectedEndOfInput, InvalidLeftHandSideInAssignmentExpression } || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError;

    // Parse a string into an AST.
    pub fn parse(self: *Parser, string: []const u8) Error!Program {
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
    fn statementList(self: *Parser, stopLookahead: ?Tokenizer.TokenType) Error![]Statement {
        var _statementList = std.ArrayList(Statement).init(self.allocator);
        while (self.lookahead != null and self.lookahead.?.type != stopLookahead) {
            try _statementList.append(try self.statement());
        }

        return _statementList.toOwnedSlice();
    }

    const Statement = union(enum) { ExpressionStatement: ExpressionStatement, BlockStatement: BlockStatement, EmptyStatement: EmptyStatement, VariableStatement: VariableStatement };

    // Statement
    //  : ExpressionStatement
    //  | BlockStatement
    //  | EmptyStatement
    //  | VariableStatement
    //  ;
    fn statement(self: *Parser) !Statement {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .OpenBrace => Statement{ .BlockStatement = try self.blockStatement() },
                .SemiColon => Statement{ .EmptyStatement = try self.emptyStatement() },
                .Let => Statement{ .VariableStatement = try self.variableStatement() },
                else => Statement{ .ExpressionStatement = try self.expressionStatement() },
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    const VariableStatement = struct { declarations: []VariableDeclaration };

    // VariableStatement
    //  : 'let' VariableDeclarationList ';'
    //  ;
    fn variableStatement(self: *Parser) !VariableStatement {
        _ = try self.eat(.Let);
        const declarations = try self.variableDeclarationList();
        _ = try self.eat(.SemiColon);

        return VariableStatement{ .declarations = declarations };
    }

    // VariableDeclarationList
    //  : VariableDeclaration
    //  | VariableDeclarationList ',' VariableDeclaration
    //  ;
    fn variableDeclarationList(self: *Parser) ![]VariableDeclaration {
        var declarations = std.ArrayList(VariableDeclaration).init(self.allocator);
        try declarations.append(try self.variableDeclaration());
        while (self.lookahead != null and self.lookahead.?.type == .Comma) {
            _ = try self.eat(.Comma);
            try declarations.append(try self.variableDeclaration());
        }

        return declarations.toOwnedSlice();
    }

    const VariableDeclaration = struct { id: Identifier, init: ?Expression };

    // VariableDeclaration
    //  : Identifier OptVariableInitializer
    //  ;
    fn variableDeclaration(self: *Parser) !VariableDeclaration {
        const id = try self.identifier();
        var initializer: ?Expression = null;

        if (self.lookahead.?.type != .SemiColon and self.lookahead.?.type != .Comma) {
            initializer = try self.variableInitializer();
        }

        return VariableDeclaration{ .id = id, .init = initializer };
    }

    // VariableInitializer
    //  : SIMPLE_ASSIGN AssignmentExpression
    //  ;
    fn variableInitializer(self: *Parser) !Expression {
        _ = try self.eat(.SimpleAssign);

        return self.assignmentExpression();
    }

    const EmptyStatement = struct {};

    // EmptyStatement
    // : ';'
    // ;
    fn emptyStatement(self: *Parser) !EmptyStatement {
        _ = try self.eat(.SemiColon);
        return EmptyStatement{};
    }

    const BlockStatement = struct { body: []Statement };

    // BlockStatement
    // '{' OptStatementList '}'
    // ;
    fn blockStatement(self: *Parser) !BlockStatement {
        _ = try self.eat(.OpenBrace);
        const body = try self.statementList(.CloseBrace);
        _ = try self.eat(.CloseBrace);

        return BlockStatement{ .body = body };
    }

    const ExpressionStatement = struct { expression: Expression };

    // ExpressionStatement
    //  : Expression ';'
    //  ;
    fn expressionStatement(self: *Parser) !ExpressionStatement {
        const _expression = try self.expression();
        _ = try self.eat(.SemiColon);
        return ExpressionStatement{ .expression = _expression };
    }

    const Expression = union(enum) { PrimaryExpression: PrimaryExpression, BinaryExpression: BinaryExpression, AssignmentExpression: AssignmentExpression };

    // Expression
    //  : AssignmentExpression
    //  ;
    fn expression(self: *Parser) Error!Expression {
        return self.assignmentExpression();
    }

    const AssignmentExpression = struct { operator: Tokenizer.Token, left: *Expression, right: *Expression };

    // TODO: Could the left-hand side expression be anything other than an identifer? If not, why not just return an Identifier?
    // AssignmentExpression
    //  : AdditiveExpression
    //  | LeftHandSideExpression AssignmentOperator AssignmentExpression
    //  ;
    fn assignmentExpression(self: *Parser) !Expression {
        const left = try self.additiveExpression();

        if (!(try self.isAssignmentOperator())) {
            return left;
        }

        var assignmentE = AssignmentExpression{ .left = try self.allocator.create(Expression), .right = try self.allocator.create(Expression), .operator = try self.assignmentOperator() };
        assignmentE.left.* = try checkValidAssignmentTarget(left);
        assignmentE.right.* = try self.assignmentExpression();

        return Expression{ .AssignmentExpression = assignmentE };
    }

    fn checkValidAssignmentTarget(node: Expression) !Expression {
        if (node == .PrimaryExpression and node.PrimaryExpression == .LeftHandSideExpression and node.PrimaryExpression.LeftHandSideExpression == .Identifier) {
            return node;
        }

        return Error.InvalidLeftHandSideInAssignmentExpression;
    }

    // Whether the lookeahead is an assignment operator.
    fn isAssignmentOperator(self: *Parser) !bool {
        if (self.lookahead) |lookahead| {
            return lookahead.type == .SimpleAssign or lookahead.type == .ComplexAssign;
        }

        return Error.UnexpectedEndOfInput;
    }

    const LeftHandSideExpression = union(enum) { Identifier: Identifier };

    // LeftHandSideExpression
    //  : Identifier
    //  ;
    fn leftHandSideExpression(self: *Parser) !LeftHandSideExpression {
        return LeftHandSideExpression{ .Identifier = try self.identifier() };
    }

    const Identifier = struct { name: []const u8 };

    // Identifier
    //  : IDENTIFIER
    //  ;
    fn identifier(self: *Parser) !Identifier {
        const name = (try self.eat(.Identifier)).value;
        return Identifier{ .name = name };
    }

    // AssignmentOperator
    //  : SIMPLE_ASSIGN
    //  | COMPLEX_ASSIGN
    //  ;
    fn assignmentOperator(self: *Parser) !Tokenizer.Token {
        if (self.lookahead) |lookahead| {
            if (lookahead.type == .SimpleAssign) {
                return self.eat(.SimpleAssign);
            }
            return self.eat(.ComplexAssign);
        }

        return Error.UnexpectedEndOfInput;
    }

    // AdditiveExpression
    //  : MultiplicativeExpression
    //  | AdditiveExpression ADDITIVE_OPERATOR MultiplicativeExpression
    //  ;
    fn additiveExpression(self: *Parser) !Expression {
        return self.binaryExpression(multiplicativeExpression, .AdditiveOperator);
    }

    // MultiplicativeExpression
    //  : PrimaryExpression
    //  | MultiplicativeExpression MULTIPLICATIVE_OPERATOR PrimaryExpression
    //  ;
    fn multiplicativeExpression(self: *Parser) !Expression {
        return self.binaryExpression(primaryExpression, .MultiplicativeOperator);
    }

    const BinaryExpression = struct { operator: Tokenizer.Token, left: *Expression, right: *Expression };

    // Generic Binary Expression
    fn binaryExpression(self: *Parser, comptime builderName: fn (*Parser) (Error)!Expression, comptime operatorType: Tokenizer.TokenType) !Expression {
        var left = try builderName(self);
        while (self.lookahead != null and self.lookahead.?.type == operatorType) {
            const operator = try self.eat(operatorType);
            var right = try builderName(self);
            var binaryE = BinaryExpression{ .left = try self.allocator.create(Expression), .right = try self.allocator.create(Expression), .operator = operator };
            binaryE.left.* = left;
            binaryE.right.* = right;
            left = Expression{ .BinaryExpression = binaryE };
        }

        return left;
    }

    const PrimaryExpression = union(enum) { Literal: Literal, LeftHandSideExpression: LeftHandSideExpression };

    // PrimaryExpression
    //  : Literal
    //  | ParenthesizedExpression
    //  | LeftHandSideExpression
    //  ;
    fn primaryExpression(self: *Parser) !Expression {
        if (try self.isLiteral()) {
            return Expression{ .PrimaryExpression = PrimaryExpression{ .Literal = try self.literal() } };
        }

        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .OpenPran => self.parenthesizedExpression(),
                else => Expression{ .PrimaryExpression = PrimaryExpression{ .LeftHandSideExpression = try self.leftHandSideExpression() } },
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    fn isLiteral(self: *Parser) !bool {
        if (self.lookahead) |lookahead| {
            return lookahead.type == .Number or lookahead.type == .String;
        }

        return Error.UnexpectedEndOfInput;
    }

    // ParenthesizedExpression
    //  : '(' Expression ')'
    //  ;
    fn parenthesizedExpression(self: *Parser) !Expression {
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
    fn literal(self: *Parser) !Literal {
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
    fn stringLiteral(self: *Parser) !StringLiteral {
        const token = try self.eat(.String);
        return StringLiteral{ .value = token.value[1 .. token.value.len - 1] };
    }

    const NumberLiteral = struct { value: u64 };

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
                std.debug.print("{any} {any} \n", .{ token.type, tokenType });
                return Error.UnexpectedToken;
            }

            self.lookahead = try self.tokenizer.getNextToken();
            return token;
        }

        return Error.UnexpectedEndOfInput;
    }
};
