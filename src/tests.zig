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
    try testParserOutput("x = 42;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}}}}]}");
    try testParserOutput("x = y = 42;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"y\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}}}}}}]}");
    try testParserOutput("x += 2;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"ComplexAssign\",\"value\":\"+=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":2}}}}}}}}]}");
}

test "Variable" {
    try testParserOutput("let x = 42;", "{\"body\":[{\"VariableStatement\":{\"declarations\":[{\"id\":{\"name\":\"x\"},\"init\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}]}}]}");
    try testParserOutput("let x;", "{\"body\":[{\"VariableStatement\":{\"declarations\":[{\"id\":{\"name\":\"x\"},\"init\":null}]}}]}");
    try testParserOutput("let x,y=10;", "{\"body\":[{\"VariableStatement\":{\"declarations\":[{\"id\":{\"name\":\"x\"},\"init\":null},{\"id\":{\"name\":\"y\"},\"init\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":10}}}}}]}}]}");
}

test "If" {
    try testParserOutput("if(x){x = 42;}else{x = 43;}", "{\"body\":[{\"IfStatement\":{\"testE\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"consequent\":{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}}}}]}},\"alternate\":{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":43}}}}}}}}]}}}}]}");
    try testParserOutput("if(x){x = 42;}", "{\"body\":[{\"IfStatement\":{\"testE\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"consequent\":{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}}}}]}},\"alternate\":null}}]}");
}

test "Relational" {
    try testParserOutput("x + 2 > 3;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\">\"},\"left\":{\"BinaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"+\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":2}}}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":3}}}}}}}}]}");
    try testParserOutput("let y = x + 2 > 3;", "{\"body\":[{\"VariableStatement\":{\"declarations\":[{\"id\":{\"name\":\"y\"},\"init\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\">\"},\"left\":{\"BinaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"+\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":2}}}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":3}}}}}}}]}}]}");
}

test "Equality" {
    try testParserOutput("x == 2;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"EqualityOperator\",\"value\":\"==\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":2}}}}}}}}]}");
    try testParserOutput("x > 2 == true;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"EqualityOperator\",\"value\":\"==\"},\"left\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\">\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":2}}}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"BooleanLiteral\":{\"value\":true}}}}}}}}]}");
    try testParserOutput("x != false;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"EqualityOperator\",\"value\":\"!=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"BooleanLiteral\":{\"value\":false}}}}}}}}]}");
    try testParserOutput("x != null;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"EqualityOperator\",\"value\":\"!=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NullLiteral\":{}}}}}}}}]}");
}

test "Logical" {
    try testParserOutput("x > 1 && y < 2 || z > 3;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"LogicalExpression\":{\"operator\":{\"type\":\"LogicalOr\",\"value\":\"||\"},\"left\":{\"LogicalExpression\":{\"operator\":{\"type\":\"LogicalAnd\",\"value\":\"&&\"},\"left\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\">\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}}}},\"right\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\"<\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"y\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":2}}}}}}}},\"right\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\">\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"z\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":3}}}}}}}}}}]}");
}

test "Unary" {
    try testParserOutput("!x;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"UnaryExpression\":{\"operator\":{\"type\":\"LogicalNot\",\"value\":\"!\"},\"argument\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}}}}}}]}");
    try testParserOutput("-+x;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"UnaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"-\"},\"argument\":{\"UnaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"+\"},\"argument\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}}}}}}}}]}");
}
