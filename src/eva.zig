const std = @import("std");
const Parser = @import("parser.zig").Parser;
const Environment = @import("environment.zig").Environment;

pub const Eva = struct {
    allocator: std.mem.Allocator,
    global: Environment,

    pub fn init(allocator: std.mem.Allocator) !Eva {
        var global = Environment.init(allocator, null);
        _ = try global.define("VERSION", EvalResult{ .String = "0.0.1" });

        return Eva{ .allocator = allocator, .global = Environment.init(allocator, null) };
    }

    pub const Error = error{ InvalidOperandTypes, UnimplementedStatement } || Environment.Error || std.mem.Allocator.Error;

    pub const EvalResult = union(enum) { Number: u64, String: []const u8, Null: void, Bool: bool };

    pub fn eval(self: *Eva, statement: Parser.Statement, env: *Environment) Error!EvalResult {
        return switch (statement) {
            .ExpressionStatement => |exprStmt| self.evalExpression(exprStmt.expression, env),
            .VariableStatement => |varStmt| self.evalVariableStatement(varStmt, env),
            .BlockStatement => |blockStmt| self.evalBlockStatement(blockStmt, env),
            .IfStatement => |ifStmt| self.evalIfStatement(ifStmt, env),
            .WhileStatement => |whileStmt| self.evalWhileStatement(whileStmt, env),
            .DoWhileStatement => |doWhileStmt| self.evalDoWhileStatement(doWhileStmt, env),
            else => Error.UnimplementedStatement,
        };
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
        switch (exp) {
            .Literal => |literal| {
                return self.evalLiteral(literal);
            },
            .BinaryExpression => |binaryExp| {
                return self.evalBinaryExpression(binaryExp, env);
            },
            .Identifier => |identifier| {
                return env.lookup(identifier.name);
            },
            .AssignmentExpression => |assignmentExp| {
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
            },
            else => {
                unreachable;
            },
        }

        return EvalResult{ .Null = {} };
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

    pub fn displayResult(result: EvalResult) void {
        switch (result) {
            .Number => |number| {
                std.debug.print("{}\n", .{number});
            },
            .String => |string| {
                std.debug.print("'{s}'\n", .{string});
            },
            .Null => {
                std.debug.print("null\n", .{});
            },
            .Bool => |boolean| {
                std.debug.print("{}\n", .{boolean});
            },
        }
    }
};
