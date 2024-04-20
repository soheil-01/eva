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

    pub const Error = error{ UnexpectedToken, UnexpectedEndOfInput, InvalidLeftHandSideInAssignmentExpression, UnexpectedPrimaryExpression } || Tokenizer.Error || std.mem.Allocator.Error || std.fmt.ParseIntError;

    // Parse a string into an AST.
    pub fn parse(self: *Parser, string: []const u8) Error!Program {
        self.string = string;
        self.tokenizer = Tokenizer.init(self.allocator, string);

        self.lookahead = try self.tokenizer.getNextToken();

        return self.program();
    }

    pub const Program = struct { body: []Statement };

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

    pub const Statement = union(enum) { ExpressionStatement: ExpressionStatement, BlockStatement: BlockStatement, EmptyStatement: EmptyStatement, VariableStatement: VariableStatement, IfStatement: IfStatement, WhileStatement: WhileStatement, DoWhileStatement: DoWhileStatement, ForStatement: ForStatement, FunctionDeclaration: FunctionDeclaration, ReturnStatement: ReturnStatement, ClassDeclaration: ClassDeclaration };

    // Statement
    //  : ExpressionStatement
    //  | BlockStatement
    //  | EmptyStatement
    //  | VariableStatement
    //  | IfStatement
    //  | IterationStatement
    //  | FunctionDeclaration
    //  | ReturnStatement
    //  | ClassDeclaration
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
                .Class => Statement{ .ClassDeclaration = try self.classDeclaration() },
                else => Statement{ .ExpressionStatement = try self.expressionStatement() },
            };
        }

        return Error.UnexpectedEndOfInput;
    }

    pub const ClassDeclaration = struct { id: Identifier, superClass: ?Identifier, body: BlockStatement };

    // ClassDeclaration
    //  : 'class' Identifier OptClassExtends BlockStatement
    fn classDeclaration(self: *Parser) !ClassDeclaration {
        _ = try self.eat(.Class);

        const id = try self.identifier();
        const superClass: ?Identifier = if (self.lookahead.?.type == .Extends) try self.classExtends() else null;
        const body = try self.blockStatement();

        return ClassDeclaration{ .id = id, .superClass = superClass, .body = body };
    }

    // ClassExtends
    //  : 'extends' Identifier
    //  ;
    fn classExtends(self: *Parser) !Identifier {
        _ = try self.eat(.Extends);
        return self.identifier();
    }

    pub const FunctionDeclaration = struct { name: Identifier, params: []Identifier, body: BlockStatement };

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

    pub const ReturnStatement = struct { argument: ?Expression };

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

    pub const WhileStatement = struct { testE: Expression, body: *Statement };

    // WhileStatement
    //  : 'while' '(' Expression ')' Statement
    //  ;
    fn whileStatement(self: *Parser) !WhileStatement {
        _ = try self.eat(.While);
        _ = try self.eat(.OpenPran);

        const testE = try self.expression();
        _ = try self.eat(.ClosePran);

        const _whileStatement = WhileStatement{ .testE = testE, .body = try self.allocator.create(Statement) };
        _whileStatement.body.* = try self.statement();

        return _whileStatement;
    }

    pub const DoWhileStatement = struct { testE: Expression, body: *Statement };

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

        const _doWhileStatement = DoWhileStatement{ .testE = testE, .body = try self.allocator.create(Statement) };
        _doWhileStatement.body.* = body;

        return _doWhileStatement;
    }

    pub const ForStatement = struct { init: ?ForStatementInit, testE: ?Expression, update: ?Expression, body: *Statement };

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

        const _forStatement = ForStatement{ .init = initS, .testE = testE, .update = update, .body = try self.allocator.create(Statement) };
        _forStatement.body.* = body;

        return _forStatement;
    }

    pub const ForStatementInit = union(enum) { VariableStatement: VariableStatement, Expression: Expression };

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

    pub const IfStatement = struct { testE: Expression, consequent: *Statement, alternate: ?*Statement };

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

    pub const VariableStatement = struct { declarations: []VariableDeclaration };

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

    pub const VariableDeclaration = struct { id: Identifier, init: ?Expression };

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

    pub const EmptyStatement = struct {};

    // EmptyStatement
    // : ';'
    // ;
    fn emptyStatement(self: *Parser) !EmptyStatement {
        _ = try self.eat(.SemiColon);
        return EmptyStatement{};
    }

    pub const BlockStatement = struct { body: []Statement };

    // BlockStatement
    // '{' OptStatementList '}'
    // ;
    fn blockStatement(self: *Parser) !BlockStatement {
        _ = try self.eat(.OpenBrace);
        const body = try self.statementList(.CloseBrace);
        _ = try self.eat(.CloseBrace);

        return BlockStatement{ .body = body };
    }

    pub const ExpressionStatement = struct { expression: Expression };

    // ExpressionStatement
    //  : Expression ';'
    //  ;
    fn expressionStatement(self: *Parser) !ExpressionStatement {
        const _expression = try self.expression();
        _ = try self.eat(.SemiColon);

        return ExpressionStatement{ .expression = _expression };
    }

    pub const Expression = union(enum) { Literal: Literal, Identifier: Identifier, BinaryExpression: BinaryExpression, AssignmentExpression: AssignmentExpression, LogicalExpression: LogicalExpression, UnaryExpression: UnaryExpression, MemberExpression: MemberExpression, CallExpression: CallExpression, ThisExpression: ThisExpression, Super: Super, NewExpression: NewExpression };

    // Expression
    //  : AssignmentExpression
    //  ;
    fn expression(self: *Parser) Error!Expression {
        return self.assignmentExpression();
    }

    pub const AssignmentExpression = struct { operator: Tokenizer.Token, left: *Expression, right: *Expression };

    // AssignmentExpression
    //  : LogicalORExpression
    //  | LogicalORExpression AssignmentOperator AssignmentExpression
    //  ;
    fn assignmentExpression(self: *Parser) !Expression {
        const left = try self.logicalOrExpression();

        if (!(try self.isAssignmentOperator())) {
            return left;
        }

        const assignmentE = AssignmentExpression{ .left = try self.allocator.create(Expression), .right = try self.allocator.create(Expression), .operator = try self.assignmentOperator() };
        assignmentE.left.* = try checkValidAssignmentTarget(left);
        assignmentE.right.* = try self.assignmentExpression();

        return Expression{ .AssignmentExpression = assignmentE };
    }

    fn checkValidAssignmentTarget(node: Expression) !Expression {
        if (node == .Identifier or node == .MemberExpression) {
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

    pub const Identifier = struct { name: []const u8 };

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

    pub const BinaryExpression = struct { operator: Tokenizer.Token, left: *Expression, right: *Expression };

    // Generic Binary Expression
    fn binaryExpression(self: *Parser, comptime builderName: fn (*Parser) (Error)!Expression, comptime operatorType: Tokenizer.TokenType) !Expression {
        var left = try builderName(self);
        while (self.lookahead != null and self.lookahead.?.type == operatorType) {
            const operator = try self.eat(operatorType);
            const right = try builderName(self);
            const binaryE = BinaryExpression{ .left = try self.allocator.create(Expression), .right = try self.allocator.create(Expression), .operator = operator };
            binaryE.left.* = left;
            binaryE.right.* = right;
            left = Expression{ .BinaryExpression = binaryE };
        }

        return left;
    }

    pub const LogicalExpression = struct { operator: Tokenizer.Token, left: *Expression, right: *Expression };

    // Generic Logical Expression
    fn logicalExpression(self: *Parser, comptime builderName: fn (*Parser) (Error)!Expression, comptime operatorType: Tokenizer.TokenType) !Expression {
        var left = try builderName(self);
        while (self.lookahead != null and self.lookahead.?.type == operatorType) {
            const operator = try self.eat(operatorType);
            const right = try builderName(self);
            const logicalE = LogicalExpression{ .left = try self.allocator.create(Expression), .right = try self.allocator.create(Expression), .operator = operator };
            logicalE.left.* = left;
            logicalE.right.* = right;
            left = Expression{ .LogicalExpression = logicalE };
        }

        return left;
    }

    pub const UnaryExpression = struct { operator: Tokenizer.Token, argument: *Expression };

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
    //  : CallMemberExpression
    //  ;
    fn leftHandSideExpression(self: *Parser) !Expression {
        return self.callMemberExpression();
    }

    // CallMemberExpression
    //  : MemberExpression
    //  | CallExpression
    //  ;
    fn callMemberExpression(self: *Parser) !Expression {
        // Super call
        if (self.lookahead.?.type == .Super) {
            return self.callExpression(Expression{ .Super = try self.super() });
        }

        const member = try self.memberExpression();

        if (self.lookahead.?.type == .OpenPran) {
            return self.callExpression(member);
        }

        return member;
    }

    pub const CallExpression = struct { callee: *Expression, arguments: []Expression };

    // CallExpression
    //  : Callee Arguments
    //  ;
    fn callExpression(self: *Parser, callee: Expression) !Expression {
        var callE = Expression{ .CallExpression = CallExpression{ .callee = try self.allocator.create(Expression), .arguments = try self.arguments() } };
        callE.CallExpression.callee.* = callee;

        if (self.lookahead.?.type == .OpenPran) {
            callE = try self.callExpression(callE);
        }

        return callE;
    }

    // Arguments
    //  : '(' OptArgumentList ')'
    //  ;
    fn arguments(self: *Parser) Error![]Expression {
        _ = try self.eat(.OpenPran);
        const _argumentList: []Expression = if (self.lookahead.?.type != .ClosePran) try self.argumentList() else &[_]Expression{};
        _ = try self.eat(.ClosePran);

        return _argumentList;
    }

    // ArgumentList
    //  : AssignmentExpression
    //  | ArgumentList ',' AssignmentExpression
    //  ;
    fn argumentList(self: *Parser) ![]Expression {
        var _argumentList = std.ArrayList(Expression).init(self.allocator);
        try _argumentList.append(try self.assignmentExpression());

        while (self.lookahead.?.type == .Comma) {
            _ = try self.eat(.Comma);
            try _argumentList.append(try self.assignmentExpression());
        }

        return _argumentList.toOwnedSlice();
    }

    pub const MemberExpressionProperty = union(enum) { Expression: *Expression, Identifier: Identifier };
    pub const MemberExpression = struct { computed: bool, object: *Expression, property: MemberExpressionProperty };

    // MemberExpression
    //  : PrimaryExpression
    //  | MemberExpression '.' Identifier
    //  | MemberExpression '[' Expression ']'
    //  ;
    fn memberExpression(self: *Parser) Error!Expression {
        var object = try self.primaryExpression();

        while (self.lookahead.?.type == .Dot or self.lookahead.?.type == .OpenBracket) {
            // MemberExpression '.' Identifier
            if (self.lookahead.?.type == .Dot) {
                _ = try self.eat(.Dot);
                const property = MemberExpressionProperty{ .Identifier = try self.identifier() };
                const _memberExpression = MemberExpression{ .computed = false, .object = try self.allocator.create(Expression), .property = property };
                _memberExpression.object.* = object;
                object = Expression{ .MemberExpression = _memberExpression };
            }

            // MemberExpression '[' Expression ']'
            if (self.lookahead.?.type == .OpenBracket) {
                _ = try self.eat(.OpenBracket);
                const property = MemberExpressionProperty{ .Expression = try self.allocator.create(Expression) };
                property.Expression.* = try self.expression();
                _ = try self.eat(.CloseBracket);
                const _memberExpression = MemberExpression{ .computed = true, .object = try self.allocator.create(Expression), .property = property };
                _memberExpression.object.* = object;
                object = Expression{ .MemberExpression = _memberExpression };
            }
        }

        return object;
    }

    pub const ThisExpression = struct {};

    // ThisExpression
    //  : 'this'
    //  ;
    fn thisExpression(self: *Parser) !ThisExpression {
        _ = try self.eat(.This);
        return ThisExpression{};
    }

    pub const Super = struct {};

    // Super
    //  : 'super'
    //  ;
    fn super(self: *Parser) !Super {
        _ = try self.eat(.Super);
        return Super{};
    }

    pub const NewExpression = struct { callee: *Expression, arguments: []Expression };

    // NewExpression
    //  : 'new' MemberExpression Arguments
    //  ;
    fn newExpression(self: *Parser) !NewExpression {
        _ = try self.eat(.New);
        const callee = try self.memberExpression();
        const newE = NewExpression{ .callee = try self.allocator.create(Expression), .arguments = try self.arguments() };
        newE.callee.* = callee;

        return newE;
    }

    // PrimaryExpression
    //  : Literal
    //  | ParenthesizedExpression
    //  | Identifier
    //  | ThisExpression
    //  | NewExpression
    //  ;
    fn primaryExpression(self: *Parser) !Expression {
        if (try self.isLiteral()) {
            return Expression{ .Literal = try self.literal() };
        }

        if (self.lookahead) |lookahead| {
            return switch (lookahead.type) {
                .OpenPran => self.parenthesizedExpression(),
                .Identifier => Expression{ .Identifier = try self.identifier() },
                .This => Expression{ .ThisExpression = try self.thisExpression() },
                .New => Expression{ .NewExpression = try self.newExpression() },
                else => Error.UnexpectedPrimaryExpression,
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

    pub const Literal = union(enum) { NumericLiteral: NumberLiteral, StringLiteral: StringLiteral, BooleanLiteral: BooleanLiteral, NullLiteral: NullLiteral };

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

    pub const BooleanLiteral = struct { value: bool };

    // BooleanLiteral
    //  : 'true'
    //  | 'false'
    //  ;
    fn booleanLiteral(self: *Parser, value: bool) !BooleanLiteral {
        _ = try self.eat(if (value) .True else .False);

        return BooleanLiteral{ .value = value };
    }

    pub const NullLiteral = struct {};

    // NullLiteral
    //  : 'null'
    //  ;
    fn nullLiteral(self: *Parser) !NullLiteral {
        _ = try self.eat(.Null);

        return NullLiteral{};
    }

    pub const StringLiteral = struct { value: []const u8 };

    // StringLiteral
    //  : String
    //  ;
    fn stringLiteral(self: *Parser) !StringLiteral {
        const token = try self.eat(.String);
        return StringLiteral{ .value = token.value[1 .. token.value.len - 1] };
    }

    pub const NumberLiteral = struct { value: u64 };

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
                std.debug.print("{any}\n", .{token.type});
                return Error.UnexpectedToken;
            }

            self.lookahead = try self.tokenizer.getNextToken();
            return token;
        }

        return Error.UnexpectedEndOfInput;
    }
};
