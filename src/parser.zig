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

    const Statement = union(enum) { ExpressionStatement: ExpressionStatement, BlockStatement: BlockStatement, EmptyStatement: EmptyStatement, VariableStatement: VariableStatement, IfStatement: IfStatement, WhileStatement: WhileStatement, DoWhileStatement: DoWhileStatement, ForStatement: ForStatement, FunctionDeclaration: FunctionDeclaration, ReturnStatement: ReturnStatement };

    // Statement
    //  : ExpressionStatement
    //  | BlockStatement
    //  | EmptyStatement
    //  | VariableStatement
    //  | IfStatement
    //  | IterationStatement
    //  | FunctionDeclaration
    //  | ReturnStatement
    //  ;
    fn statement(self: *Parser) Error!Statement {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .OpenBrace => Statement{ .BlockStatement = try self.blockStatement() },
                .SemiColon => Statement{ .EmptyStatement = try self.emptyStatement() },
                .Let => Statement{ .VariableStatement = try self.variableStatement() },
                .If => Statement{ .IfStatement = try self.ifStatement() },
                .While, .Do, .For => self.iterationStatement(),
                .Def => Statement{ .FunctionDeclaration = try self.functionDeclaration() },
                .Return => Statement{ .ReturnStatement = try self.returnStatement() },
                else => Statement{ .ExpressionStatement = try self.expressionStatement() },
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    const FunctionDeclaration = struct { name: Identifier, params: []Identifier, body: BlockStatement };

    // FunctionDeclaration
    //  : 'def' Identifier '(' OptFormalParameterList ')' BlockStatement
    //  ;
    fn functionDeclaration(self: *Parser) !FunctionDeclaration {
        _ = try self.eat(.Def);
        const name = try self.identifier();

        _ = try self.eat(.OpenPran);

        const params: []Identifier = if (self.lookahead.?.type != .ClosePran) try self.formalParameterList() else &[_]Identifier{};

        _ = try self.eat(.ClosePran);
        const body = try self.blockStatement();

        return FunctionDeclaration{ .name = name, .params = params, .body = body };
    }

    // FormalParameterList
    //  : Identifer
    //  | FormalParameterList ',' Identifier
    //  ;
    fn formalParameterList(self: *Parser) ![]Identifier {
        var params = std.ArrayList(Identifier).init(self.allocator);
        try params.append(try self.identifier());

        while (self.lookahead.?.type == .Comma) {
            _ = try self.eat(.Comma);
            try params.append(try self.identifier());
        }

        return params.toOwnedSlice();
    }

    const ReturnStatement = struct { argument: ?Expression };

    // ReturnStatement
    //  : 'return' OptExpression ';'
    //  ;
    fn returnStatement(self: *Parser) !ReturnStatement {
        _ = try self.eat(.Return);
        const argument: ?Expression = if (self.lookahead.?.type != .SemiColon) try self.expression() else null;
        _ = try self.eat(.SemiColon);

        return ReturnStatement{ .argument = argument };
    }

    // IterationStatement
    //  : WhileStatement
    //  | DoWhileStatement
    //  | ForStatement
    //  ;
    fn iterationStatement(self: *Parser) !Statement {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .While => Statement{ .WhileStatement = try self.whileStatement() },
                .Do => Statement{ .DoWhileStatement = try self.doWhileStatement() },
                .For => Statement{ .ForStatement = try self.forStatement() },
                else => Error.UnexpectedToken,
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    const WhileStatement = struct { testE: Expression, body: *Statement };

    // WhileStatement
    //  : 'while' '(' Expression ')' Statement
    //  ;
    fn whileStatement(self: *Parser) !WhileStatement {
        _ = try self.eat(.While);
        _ = try self.eat(.OpenPran);

        const testE = try self.expression();
        _ = try self.eat(.ClosePran);

        var _whileStatement = WhileStatement{ .testE = testE, .body = try self.allocator.create(Statement) };
        _whileStatement.body.* = try self.statement();

        return _whileStatement;
    }

    const DoWhileStatement = struct { testE: Expression, body: *Statement };

    // DoWhileStatement
    //  : 'do' Statement 'while' '(' Expression ')' ';'
    //  ;
    fn doWhileStatement(self: *Parser) !DoWhileStatement {
        _ = try self.eat(.Do);

        const body = try self.statement();

        _ = try self.eat(.While);
        _ = try self.eat(.OpenPran);

        const testE = try self.expression();

        _ = try self.eat(.ClosePran);
        _ = try self.eat(.SemiColon);

        var _doWhileStatement = DoWhileStatement{ .testE = testE, .body = try self.allocator.create(Statement) };
        _doWhileStatement.body.* = body;

        return _doWhileStatement;
    }

    const ForStatement = struct { init: ?ForStatementInit, testE: ?Expression, update: ?Expression, body: *Statement };

    // ForStatement
    //  : 'for' '(' OptForStatementInit ';' OptExpression ';' OptExpression ')' Statement
    //  ;
    fn forStatement(self: *Parser) !ForStatement {
        _ = try self.eat(.For);
        _ = try self.eat(.OpenPran);

        const initS: ?ForStatementInit = if (self.lookahead.?.type != .SemiColon) try self.forStatementInit() else null;
        _ = try self.eat(.SemiColon);

        const testE: ?Expression = if (self.lookahead.?.type != .SemiColon) try self.expression() else null;
        _ = try self.eat(.SemiColon);

        const update: ?Expression = if (self.lookahead.?.type != .ClosePran) try self.expression() else null;
        _ = try self.eat(.ClosePran);

        const body = try self.statement();

        var _forStatement = ForStatement{ .init = initS, .testE = testE, .update = update, .body = try self.allocator.create(Statement) };
        _forStatement.body.* = body;

        return _forStatement;
    }

    const ForStatementInit = union(enum) { VariableStatement: VariableStatement, Expression: Expression };

    // ForStatementInit
    //  : VariableStatementInit
    //  | Expression
    //  ;
    fn forStatementInit(self: *Parser) !ForStatementInit {
        if (self.lookahead.?.type == .Let) {
            return ForStatementInit{ .VariableStatement = try self.variableStatementInit() };
        }

        return ForStatementInit{ .Expression = try self.expression() };
    }

    const IfStatement = struct { testE: Expression, consequent: *Statement, alternate: ?*Statement };

    // IfStatement
    //  : 'if' '(' Expression ')' Statement
    //  | 'if' '(' Expression ')' Statement 'else' Statement
    //  ;
    fn ifStatement(self: *Parser) !IfStatement {
        _ = try self.eat(.If);
        _ = try self.eat(.OpenPran);
        const testE = try self.expression();
        _ = try self.eat(.ClosePran);

        var _ifStatement = IfStatement{ .testE = testE, .consequent = try self.allocator.create(Statement), .alternate = try self.allocator.create(Statement) };

        _ifStatement.consequent.* = try self.statement();

        if (self.lookahead != null and self.lookahead.?.type == .Else) {
            _ = try self.eat(.Else);
            _ifStatement.alternate.?.* = try self.statement();
        } else {
            _ifStatement.alternate = null;
        }

        return _ifStatement;
    }

    const VariableStatement = struct { declarations: []VariableDeclaration };

    // VariableStatementInit
    //  : 'let' VariableDeclarationList
    //  ;
    fn variableStatementInit(self: *Parser) !VariableStatement {
        _ = try self.eat(.Let);
        const declarations = try self.variableDeclarationList();

        return VariableStatement{ .declarations = declarations };
    }

    // VariableStatement
    //  : VariableStatementInit ';'
    //  ;
    fn variableStatement(self: *Parser) !VariableStatement {
        const _variableStatement = try self.variableStatementInit();
        _ = try self.eat(.SemiColon);

        return _variableStatement;
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

        if (self.lookahead != null and self.lookahead.?.type != .SemiColon and self.lookahead.?.type != .Comma) {
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

    const Expression = union(enum) { PrimaryExpression: PrimaryExpression, BinaryExpression: BinaryExpression, AssignmentExpression: AssignmentExpression, LogicalExpression: LogicalExpression, UnaryExpression: UnaryExpression };

    // Expression
    //  : AssignmentExpression
    //  ;
    fn expression(self: *Parser) Error!Expression {
        return self.assignmentExpression();
    }

    const AssignmentExpression = struct { operator: Tokenizer.Token, left: *Expression, right: *Expression };

    // AssignmentExpression
    //  : LogicalORExpression
    //  | LeftHandSideExpression AssignmentOperator AssignmentExpression
    //  ;
    fn assignmentExpression(self: *Parser) !Expression {
        const left = try self.logicalOrExpression();

        if (!(try self.isAssignmentOperator())) {
            return left;
        }

        var assignmentE = AssignmentExpression{ .left = try self.allocator.create(Expression), .right = try self.allocator.create(Expression), .operator = try self.assignmentOperator() };
        assignmentE.left.* = try checkValidAssignmentTarget(left);
        assignmentE.right.* = try self.assignmentExpression();

        return Expression{ .AssignmentExpression = assignmentE };
    }

    fn checkValidAssignmentTarget(node: Expression) !Expression {
        if (node == .PrimaryExpression and node.PrimaryExpression == .Identifier) {
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

    // LogicalORExpression
    //  : EqualityExpression
    //  | EqualityExpression LOGICAL_OR LogicalORExpression
    //  ;
    fn logicalOrExpression(self: *Parser) !Expression {
        return self.logicalExpression(logicalAndExpression, .LogicalOr);
    }

    // LogicalANDExpression
    //  : EqualityExpression
    //  | EqualityExpression LOGICAL_AND LogicalANDExpression
    //  ;
    fn logicalAndExpression(self: *Parser) !Expression {
        return self.logicalExpression(equalityExpression, .LogicalAnd);
    }

    // EqualityExpression
    //  : RelationalExpression
    //  | RelationalExpression EQUALITY_OPERATOR EqualityExpression
    //  ;
    fn equalityExpression(self: *Parser) !Expression {
        return self.binaryExpression(relationalExpression, .EqualityOperator);
    }

    // RelationalExpression
    //  : AdditiveExpression
    //  | AdditiveExpression RELATIONAL_OPERATOR RelationalExpression
    //  ;
    fn relationalExpression(self: *Parser) !Expression {
        return self.binaryExpression(additiveExpression, .RelationalOperator);
    }

    // AdditiveExpression
    //  : MultiplicativeExpression
    //  | AdditiveExpression ADDITIVE_OPERATOR MultiplicativeExpression
    //  ;
    fn additiveExpression(self: *Parser) !Expression {
        return self.binaryExpression(multiplicativeExpression, .AdditiveOperator);
    }

    // MultiplicativeExpression
    //  : UnaryExpression
    //  | MultiplicativeExpression MULTIPLICATIVE_OPERATOR UnaryExpression
    //  ;
    fn multiplicativeExpression(self: *Parser) !Expression {
        return self.binaryExpression(unaryExpression, .MultiplicativeOperator);
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

    const LogicalExpression = struct { operator: Tokenizer.Token, left: *Expression, right: *Expression };

    // Generic Logical Expression
    fn logicalExpression(self: *Parser, comptime builderName: fn (*Parser) (Error)!Expression, comptime operatorType: Tokenizer.TokenType) !Expression {
        var left = try builderName(self);
        while (self.lookahead != null and self.lookahead.?.type == operatorType) {
            const operator = try self.eat(operatorType);
            var right = try builderName(self);
            var logicalE = LogicalExpression{ .left = try self.allocator.create(Expression), .right = try self.allocator.create(Expression), .operator = operator };
            logicalE.left.* = left;
            logicalE.right.* = right;
            left = Expression{ .LogicalExpression = logicalE };
        }

        return left;
    }

    const UnaryExpression = struct { operator: Tokenizer.Token, argument: *Expression };

    // UnaryExpression
    //  : LeftHandSideExpression
    //  | ADDITIVE_OPERATOR UnaryExpression
    //  | LOGICAL_NOT UnaryExpression
    //  ;
    fn unaryExpression(self: *Parser) !Expression {
        var operator: ?Tokenizer.Token = null;
        if (self.lookahead) |lookahead| {
            switch (lookahead.type) {
                .AdditiveOperator => operator = try self.eat(.AdditiveOperator),
                .LogicalNot => operator = try self.eat(.LogicalNot),
                else => {},
            }
            if (operator != null) {
                const unaryE = UnaryExpression{ .operator = operator.?, .argument = try self.allocator.create(Expression) };
                unaryE.argument.* = try self.unaryExpression();

                return Expression{ .UnaryExpression = unaryE };
            }

            return self.leftHandSideExpression();
        }

        return Error.UnexpectedEndOfInput;
    }

    // LeftHandSideExpression
    //  : PrimaryExpression
    //  ;
    fn leftHandSideExpression(self: *Parser) !Expression {
        return self.primaryExpression();
    }

    const PrimaryExpression = union(enum) { Literal: Literal, Identifier: Identifier };

    // PrimaryExpression
    //  : Literal
    //  | ParenthesizedExpression
    //  | Identifier
    //  ;
    fn primaryExpression(self: *Parser) !Expression {
        if (try self.isLiteral()) {
            return Expression{ .PrimaryExpression = PrimaryExpression{ .Literal = try self.literal() } };
        }

        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .OpenPran => self.parenthesizedExpression(),
                .Identifier => Expression{ .PrimaryExpression = .{ .Identifier = try self.identifier() } },
                else => Error.UnexpectedToken,
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    fn isLiteral(self: *Parser) !bool {
        if (self.lookahead) |lookahead| {
            return lookahead.type == .Number or lookahead.type == .String or lookahead.type == .True or lookahead.type == .False or lookahead.type == .Null;
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

    const Literal = union(enum) { NumericLiteral: NumberLiteral, StringLiteral: StringLiteral, BooleanLiteral: BooleanLiteral, NullLiteral: NullLiteral };

    // Literal
    //  : NumericLiteral
    //  | StringLiteral
    //  | BooleanLiteral
    //  | NullLiteral
    //  ;
    fn literal(self: *Parser) !Literal {
        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .Number => Literal{ .NumericLiteral = try self.numericLiteral() },
                .String => Literal{ .StringLiteral = try self.stringLiteral() },
                .True => Literal{ .BooleanLiteral = try self.booleanLiteral(true) },
                .False => Literal{ .BooleanLiteral = try self.booleanLiteral(false) },
                .Null => Literal{ .NullLiteral = try self.nullLiteral() },
                else => Error.UnexpectedToken,
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    const BooleanLiteral = struct { value: bool };

    // BooleanLiteral
    //  : 'true'
    //  | 'false'
    //  ;
    fn booleanLiteral(self: *Parser, value: bool) !BooleanLiteral {
        _ = try self.eat(if (value) .True else .False);

        return BooleanLiteral{ .value = value };
    }

    const NullLiteral = struct {};

    // NullLiteral
    //  : 'null'
    //  ;
    fn nullLiteral(self: *Parser) !NullLiteral {
        _ = try self.eat(.Null);

        return NullLiteral{};
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
                return Error.UnexpectedToken;
            }

            self.lookahead = try self.tokenizer.getNextToken();
            return token;
        }

        return Error.UnexpectedEndOfInput;
    }
};
