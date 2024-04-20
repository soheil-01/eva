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

    pub const EvalResult = union(enum) { Number: u64, String: []const u8, Null: void };

    pub fn eval(self: *Eva, statement: Parser.Statement, env: *Environment) Error!EvalResult {
        switch (statement) {
            .ExpressionStatement => |exprStmt| {
                return self.evalExpression(exprStmt.expression, env);
            },
            .VariableStatement => |varStmt| {
                for (varStmt.declarations) |declaration| {
                    try env.define(declaration.id.name, if (declaration.init) |exp| try self.evalExpression(exp, env) else EvalResult{ .Null = {} });
                    return EvalResult{ .Null = {} };
                }
            },
            .BlockStatement => |blockStmt| {
                var blockEnv = Environment.init(self.allocator, env);
                var result = EvalResult{ .Null = {} };
                for (blockStmt.body) |stmt| {
                    result = try self.eval(stmt, &blockEnv);
                }

                return result;
            },
            else => {
                unreachable;
            },
        }

        return Error.UnimplementedStatement;
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
                                try env.assign(identifier.name, try self.evalExpression(right, env));
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

        switch (operator.type) {
            .AdditiveOperator, .MultiplicativeOperator => {
                if (left != .Number or right != .Number) {
                    return Error.InvalidOperandTypes;
                }

                switch (operator.value[0]) {
                    '+' => {
                        return EvalResult{ .Number = left.Number + right.Number };
                    },
                    '-' => {
                        return EvalResult{ .Number = left.Number - right.Number };
                    },
                    '*' => {
                        return EvalResult{ .Number = left.Number * right.Number };
                    },
                    '/' => {
                        return EvalResult{ .Number = left.Number / right.Number };
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

    fn evalLiteral(self: *Eva, literal: Parser.Literal) !EvalResult {
        _ = self;

        switch (literal) {
            .NumericLiteral => |numericLiteral| {
                return EvalResult{ .Number = numericLiteral.value };
            },
            .StringLiteral => |stringLiteral| {
                return EvalResult{ .String = stringLiteral.value };
            },
            else => {
                unreachable;
            },
        }
    }

    pub fn displayResult(self: *Eva, result: EvalResult) void {
        _ = self;

        return switch (result) {
            .Number => |number| {
                std.debug.print("{}\n", .{number});
            },
            .String => |string| {
                std.debug.print("'{s}'\n", .{string});
            },
            .Null => {
                std.debug.print("null\n", .{});
            },
        };
    }
};
