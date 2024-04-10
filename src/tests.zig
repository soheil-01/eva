const std = @import("std");
const Parser = @import("parser.zig").Parser;

// TODO: Using std.testing.allocator would cause a memory leak
const allocator = std.heap.page_allocator;

fn testParserOutput(program: []const u8, expected: []const u8) !void {
    var parser = Parser.init(allocator);
    const ast = try parser.parse(program);
    const string = try std.json.stringifyAlloc(allocator, ast, .{});
    try std.testing.expectEqualStrings(expected, string);
}

test "Literals" {
    try testParserOutput("42;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}}]}");
    try testParserOutput("\"hello\";", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}}]}");
    try testParserOutput("'hello';", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}}]}");
}

test "StatementList" {
    try testParserOutput(
        \\ "hello";
        \\ // Comment
        \\ 42;
    , "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}},{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}}]}");
}

test "Block" {
    try testParserOutput("{42; 'hello';}", "{\"body\":[{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}},{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}}]}}]}");
    try testParserOutput("{ }", "{\"body\":[{\"BlockStatement\":{\"body\":[]}}]}");
    try testParserOutput("{ 42; { 'hello'; } }", "{\"body\":[{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}},{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"PrimaryExpression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}}]}}]}}]}");
}

test "Empty Statement" {
    try testParserOutput(";", "{\"body\":[{\"EmptyStatement\":{}}]}");
}

test "Math" {
    try testParserOutput("42 + 43;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"+\"},\"left\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":43}}}}}}}}]}");
    try testParserOutput("42 - 43 + 44;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"+\"},\"left\":{\"BinaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"-\"},\"left\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":43}}}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":44}}}}}}}}]}");
    try testParserOutput("42 * 43;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"MultiplicativeOperator\",\"value\":\"*\"},\"left\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":43}}}}}}}}]}");
    try testParserOutput("42 + 43 * 44;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"+\"},\"left\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}},\"right\":{\"BinaryExpression\":{\"operator\":{\"type\":\"MultiplicativeOperator\",\"value\":\"*\"},\"left\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":43}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":44}}}}}}}}}}]}");
    try testParserOutput("(42 + 43) * 44;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"MultiplicativeOperator\",\"value\":\"*\"},\"left\":{\"BinaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"+\"},\"left\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":43}}}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":44}}}}}}}}]}");
}

test "Assignment" {
    try testParserOutput("x = 42;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"LeftHandSideExpression\":{\"Identifier\":{\"name\":\"x\"}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}}}}]}");
    try testParserOutput("x = y = 42;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"LeftHandSideExpression\":{\"Identifier\":{\"name\":\"x\"}}}},\"right\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"LeftHandSideExpression\":{\"Identifier\":{\"name\":\"y\"}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}}}}}}]}");
    try testParserOutput("x += 2;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"ComplexAssign\",\"value\":\"+=\"},\"left\":{\"PrimaryExpression\":{\"LeftHandSideExpression\":{\"Identifier\":{\"name\":\"x\"}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":2}}}}}}}}]}");
}
