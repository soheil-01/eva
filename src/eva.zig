const std = @import("std");
const Parser = @import("parser.zig").Parser;
const Environment = @import("environment.zig").Environment;

pub const Eva = struct {
    allocator: std.mem.Allocator,
    global: Environment,

    pub fn init(allocator: std.mem.Allocator) !Eva {
        var global = Environment.init(allocator, null);
        _ = try global.define("VERSION", EvalResult{ .String = "0.0.1" });
        _ = try global.define("print", EvalResult{ .Function = .{ .Native = .{ .Print = {} } } });

        return Eva{ .allocator = allocator, .global = global };
    }

    pub const Error = error{ InvalidOperandTypes, UnimplementedStatement, UnimplementedExpression } || Environment.Error || std.mem.Allocator.Error;

    const NativeFunction = union(enum) {
        Print,

        fn call(self: NativeFunction, args: []EvalResult, allocator: std.mem.Allocator) !EvalResult {
            switch (self) {
                .Print => {
                    for (args, 0..) |arg, i| {
                        std.debug.print("{s}", .{try arg.toString(allocator)});
                        if (i < args.len - 1) {
                            std.debug.print(" ", .{});
                        }
                    }
                    std.debug.print("\n", .{});

                    return EvalResult{ .Null = {} };
                },
            }
        }
    };

    const UserDefinedFunction = struct {
        params: []Parser.Identifier,
        body: Parser.BlockStatement,
        env: *Environment,
    };

    const LambdaFunction = struct { params: []Parser.Identifier, body: Parser.LambdaExpressionBody, env: *Environment };

    const Function = union(enum) { Native: NativeFunction, UserDefined: UserDefinedFunction, Lambda: LambdaFunction };

    pub const EvalResult = union(enum) {
        Number: u64,
        String: []const u8,
        Null: void,
        Bool: bool,
        Function: Function,
        Return: ?*EvalResult,

        pub fn toString(self: EvalResult, allocator: std.mem.Allocator) ![]u8 {
            return switch (self) {
                .Number => |number| std.fmt.allocPrint(allocator, "{}", .{number}),
                .String => |string| std.fmt.allocPrint(allocator, "{s}", .{string}),
                .Null => std.fmt.allocPrint(allocator, "null", .{}),
                .Bool => |boolean| std.fmt.allocPrint(allocator, "{}", .{boolean}),
                .Function => std.fmt.allocPrint(allocator, "<fn>", .{}),
                .Return => {
                    unreachable;
                },
            };
        }

        pub fn display(self: EvalResult, allocator: std.mem.Allocator) !void {
            std.debug.print("{s}\n", .{try self.toString(allocator)});
        }
    };

    pub fn evalProgram(self: *Eva, program: Parser.Program) Error!EvalResult {
        var result = EvalResult{ .Null = {} };
        for (program.body) |statement| {
            result = try self.eval(statement, &self.global);
        }

        return result;
    }

    pub fn eval(self: *Eva, statement: Parser.Statement, env: *Environment) Error!EvalResult {
        return switch (statement) {
            .ExpressionStatement => |exprStmt| self.evalExpression(exprStmt.expression, env),
            .VariableStatement => |varStmt| self.evalVariableStatement(varStmt, env),
            .BlockStatement => |blockStmt| self.evalBlockStatement(blockStmt, env),
            .IfStatement => |ifStmt| self.evalIfStatement(ifStmt, env),
            .WhileStatement => |whileStmt| self.evalWhileStatement(whileStmt, env),
            .DoWhileStatement => |doWhileStmt| self.evalDoWhileStatement(doWhileStmt, env),
            .ForStatement => |forStmt| self.evalForStatement(forStmt, env),
            .EmptyStatement => EvalResult{ .Null = {} },
            .FunctionDeclaration => |functionDeclaration| self.evalFunctionDeclaration(functionDeclaration, env),
            .ReturnStatement => |returnStmt| self.evalReturnStatement(returnStmt, env),
            else => Error.UnimplementedStatement,
        };
    }

    fn evalReturnStatement(self: *Eva, returnStmt: Parser.ReturnStatement, env: *Environment) Error!EvalResult {
        var result = EvalResult{ .Return = null };
        if (returnStmt.argument) |argument| {
            var evalResult = try self.evalExpression(argument, env);
            result = EvalResult{ .Return = &evalResult };
        }

        return result;
    }

    fn evalFunctionDeclaration(_: *Eva, functionDeclaration: Parser.FunctionDeclaration, env: *Environment) Error!EvalResult {
        const function = UserDefinedFunction{ .params = functionDeclaration.params, .body = functionDeclaration.body, .env = try env.clone() };
        try env.define(functionDeclaration.name.name, EvalResult{ .Function = .{ .UserDefined = function } });
        // TODO: find a better way to handle recursive calls
        try function.env.define(functionDeclaration.name.name, EvalResult{ .Function = .{ .UserDefined = function } });

        return EvalResult{ .Null = {} };
    }

    fn evalForStatement(self: *Eva, forStmt: Parser.ForStatement, env: *Environment) Error!EvalResult {
        var forEnv = Environment.init(self.allocator, env);

        if (forStmt.init) |initStmt| {
            _ = switch (initStmt) {
                .Expression => |exp| try self.evalExpression(exp, &forEnv),
                .VariableStatement => |variableStmt| try self.eval(Parser.Statement{ .VariableStatement = variableStmt }, &forEnv),
            };
        }

        var result = EvalResult{ .Null = {} };
        while (true) {
            if (forStmt.testE) |testE| {
                const testExpResult = try self.evalExpression(testE, &forEnv);
                if (testExpResult != .Bool or !testExpResult.Bool) {
                    break;
                }
            }

            result = try self.eval(forStmt.body.*, &forEnv);

            if (forStmt.update) |updateExp| {
                _ = try self.evalExpression(updateExp, &forEnv);
            }
        }

        return result;
    }

    fn evalDoWhileStatement(self: *Eva, doWhileStmt: Parser.DoWhileStatement, env: *Environment) Error!EvalResult {
        var result = try self.eval(doWhileStmt.body.*, env);

        while (true) {
            const testE = try self.evalExpression(doWhileStmt.testE, env);
            if (testE != .Bool or !testE.Bool) {
                break;
            }

            result = try self.eval(doWhileStmt.body.*, env);
        }

        return result;
    }

    fn evalWhileStatement(self: *Eva, whileStmt: Parser.WhileStatement, env: *Environment) Error!EvalResult {
        var result = EvalResult{ .Null = {} };

        while (true) {
            const testE = try self.evalExpression(whileStmt.testE, env);
            if (testE != .Bool or !testE.Bool) {
                break;
            }

            result = try self.eval(whileStmt.body.*, env);
        }

        return result;
    }

    fn evalIfStatement(self: *Eva, ifStmt: Parser.IfStatement, env: *Environment) Error!EvalResult {
        const testE = try self.evalExpression(ifStmt.testE, env);
        if (testE == .Bool and testE.Bool) {
            return self.eval(ifStmt.consequent.*, env);
        }

        if (ifStmt.alternate) |alternate| {
            return self.eval(alternate.*, env);
        }

        return EvalResult{ .Null = {} };
    }

    fn evalBlockStatement(self: *Eva, blockStmt: Parser.BlockStatement, env: *Environment) Error!EvalResult {
        var blockEnv = Environment.init(self.allocator, env);
        var result = EvalResult{ .Null = {} };
        for (blockStmt.body) |stmt| {
            result = try self.eval(stmt, &blockEnv);
        }

        return result;
    }

    fn evalVariableStatement(self: *Eva, varStmt: Parser.VariableStatement, env: *Environment) Error!EvalResult {
        for (varStmt.declarations) |declaration| {
            try env.define(declaration.id.name, if (declaration.init) |exp| try self.evalExpression(exp, env) else EvalResult{ .Null = {} });
        }

        return EvalResult{ .Null = {} };
    }

    fn evalExpression(self: *Eva, exp: Parser.Expression, env: *Environment) Error!EvalResult {
        return switch (exp) {
            .Literal => |literal| self.evalLiteral(literal),
            .BinaryExpression => |binaryExp| self.evalBinaryExpression(binaryExp, env),
            .Identifier => |identifier| env.lookup(identifier.name),
            .AssignmentExpression => |assignmentExp| self.evalAssignmentExpression(assignmentExp, env),
            .UnaryExpression => |unaryExp| self.evalUnaryExpression(unaryExp, env),
            .CallExpression => |callExp| self.evalCallExpression(callExp, env),
            .LambdaExpression => |lambdaExp| self.evalLambdaExpression(lambdaExp, env),
            else => Error.UnimplementedExpression,
        };
    }

    fn evalLambdaExpression(_: *Eva, lambdaExp: Parser.LambdaExpression, env: *Environment) Error!EvalResult {
        return EvalResult{ .Function = .{ .Lambda = .{ .params = lambdaExp.params, .body = lambdaExp.body, .env = try env.clone() } } };
    }

    fn evalCallExpression(self: *Eva, callExp: Parser.CallExpression, env: *Environment) Error!EvalResult {
        const callee = try self.evalExpression(callExp.callee.*, env);

        var args = std.ArrayList(EvalResult).init(self.allocator);
        for (callExp.arguments) |arg| {
            try args.append(try self.evalExpression(arg, env));
        }
        const evaluatedArgs = try args.toOwnedSlice();

        if (callee != .Function) {
            return Error.VariableIsNotDefined;
        }

        switch (callee.Function) {
            .Native => |nativeFunc| {
                return try nativeFunc.call(evaluatedArgs, self.allocator);
            },
            .UserDefined => |userDefinedFunc| {
                var activationEnv = Environment.init(self.allocator, userDefinedFunc.env);
                for (userDefinedFunc.params, 0..) |param, i| {
                    _ = try activationEnv.define(param.name, evaluatedArgs[i]);
                }

                return self.evalBody(userDefinedFunc.body, &activationEnv);
            },
            .Lambda => |lambdaFunc| {
                var activationEnv = Environment.init(self.allocator, lambdaFunc.env);
                for (lambdaFunc.params, 0..) |param, i| {
                    _ = try activationEnv.define(param.name, evaluatedArgs[i]);
                }

                return switch (lambdaFunc.body) {
                    .BlockStatement => self.evalBody(lambdaFunc.body.BlockStatement, &activationEnv),
                    .Expression => self.evalExpression(lambdaFunc.body.Expression.*, &activationEnv),
                };
            },
        }
    }

    fn evalBody(self: *Eva, blockStmt: Parser.BlockStatement, env: *Environment) Error!EvalResult {
        for (blockStmt.body) |stmt| {
            const result = try self.eval(stmt, env);
            if (result == .Return) {
                return if (result.Return) |value| value.* else EvalResult{ .Null = {} };
            }
        }

        return EvalResult{ .Null = {} };
    }

    fn evalUnaryExpression(self: *Eva, unaryExp: Parser.UnaryExpression, env: *Environment) Error!EvalResult {
        const operator = unaryExp.operator;
        const argument = try self.evalExpression(unaryExp.argument.*, env);

        switch (operator.type) {
            .LogicalNot => {
                if (argument != .Bool) {
                    return Error.InvalidOperandTypes;
                }

                return EvalResult{ .Bool = !argument.Bool };
            },
            .AdditiveOperator => {
                if (argument != .Number) {
                    return Error.InvalidOperandTypes;
                }

                return switch (operator.value[0]) {
                    '+' => argument,
                    // TODO: Add support for negative numbers
                    //'-' => EvalResult{ .Number = -argument.Number },
                    else => {
                        unreachable;
                    },
                };
            },
            else => {
                unreachable;
            },
        }
    }

    fn evalAssignmentExpression(self: *Eva, assignmentExp: Parser.AssignmentExpression, env: *Environment) Error!EvalResult {
        const left = assignmentExp.left.*;
        const right = assignmentExp.right.*;

        switch (assignmentExp.operator.type) {
            .SimpleAssign => {
                switch (left) {
                    .Identifier => |identifier| {
                        const value = try self.evalExpression(right, env);
                        try env.assign(identifier.name, value);
                        return value;
                    },
                    else => {
                        unreachable;
                    },
                }
            },
            else => {
                unreachable;
            },
        }
    }

    fn evalBinaryExpression(self: *Eva, binaryExp: Parser.BinaryExpression, env: *Environment) !EvalResult {
        const left = try self.evalExpression(binaryExp.left.*, env);
        const right = try self.evalExpression(binaryExp.right.*, env);
        const operator = binaryExp.operator;

        if (left != .Number or right != .Number) {
            return Error.InvalidOperandTypes;
        }

        switch (operator.type) {
            .AdditiveOperator, .MultiplicativeOperator => {
                return switch (operator.value[0]) {
                    '+' => EvalResult{ .Number = left.Number + right.Number },
                    '-' => EvalResult{ .Number = left.Number - right.Number },
                    '*' => EvalResult{ .Number = left.Number * right.Number },
                    '/' => EvalResult{ .Number = left.Number / right.Number },
                    else => {
                        unreachable;
                    },
                };
            },
            .RelationalOperator => {
                if (std.mem.eql(u8, operator.value, ">=")) {
                    return EvalResult{ .Bool = left.Number >= right.Number };
                }

                if (std.mem.eql(u8, operator.value, "<=")) {
                    return EvalResult{ .Bool = left.Number <= right.Number };
                }

                return switch (operator.value[0]) {
                    '>' => EvalResult{ .Bool = left.Number > right.Number },
                    '<' => EvalResult{ .Bool = left.Number < right.Number },
                    else => {
                        unreachable;
                    },
                };
            },
            .EqualityOperator => {
                if (std.mem.eql(u8, operator.value, "==")) {
                    return EvalResult{ .Bool = left.Number == right.Number };
                }

                if (std.mem.eql(u8, operator.value, "!=")) {
                    return EvalResult{ .Bool = left.Number != right.Number };
                }

                unreachable;
            },
            else => {
                unreachable;
            },
        }
    }

    fn evalLiteral(_: *Eva, literal: Parser.Literal) !EvalResult {
        return switch (literal) {
            .NumericLiteral => |numericLiteral| EvalResult{ .Number = numericLiteral.value },
            .StringLiteral => |stringLiteral| EvalResult{ .String = stringLiteral.value },
            else => {
                unreachable;
            },
        };
    }
};
