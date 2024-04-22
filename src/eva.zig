const std = @import("std");
const Parser = @import("parser.zig").Parser;
const Environment = @import("environment.zig").Environment;

pub const Eva = struct {
    allocator: std.mem.Allocator,
    global: Environment,

    pub fn init(allocator: std.mem.Allocator) !Eva {
        var global = Environment.init(allocator, null);
        _ = try global.define("VERSION", EvalResult{ .String = "0.0.1" });

        return Eva{ .allocator = allocator, .global = global };
    }

    pub const Error = error{ InvalidOperandTypes, UnimplementedStatement } || Environment.Error || std.mem.Allocator.Error;

    pub const EvalResult = union(enum) {
        Number: u64,
        String: []const u8,
        Null: void,
        Bool: bool,

        pub fn toString(self: EvalResult, allocator: std.mem.Allocator) ![]u8 {
            return switch (self) {
                .Number => |number| std.fmt.allocPrint(allocator, "{}", .{number}),
                .String => |string| std.fmt.allocPrint(allocator, "'{s}'", .{string}),
                .Null => std.fmt.allocPrint(allocator, "null", .{}),
                .Bool => |boolean| std.fmt.allocPrint(allocator, "{}", .{boolean}),
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
            else => Error.UnimplementedStatement,
        };
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
            else => EvalResult{ .Null = {} },
        };
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
