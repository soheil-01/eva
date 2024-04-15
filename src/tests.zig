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

test "While" {
    try testParserOutput("while(x<10){x += 1;}", "{\"body\":[{\"WhileStatement\":{\"testE\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\"<\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":10}}}}}},\"body\":{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"ComplexAssign\",\"value\":\"+=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}}}}}}]}}}}]}");
}

test "Do While" {
    try testParserOutput("do{x += 1;}while(x<10);", "{\"body\":[{\"DoWhileStatement\":{\"testE\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\"<\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":10}}}}}},\"body\":{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"ComplexAssign\",\"value\":\"+=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}}}}}}]}}}}]}");
}

test "For" {
    try testParserOutput("for(let x=1;x<10;x+=1){y+=1;}", "{\"body\":[{\"ForStatement\":{\"init\":{\"VariableStatement\":{\"declarations\":[{\"id\":{\"name\":\"x\"},\"init\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}}}]}},\"testE\":{\"BinaryExpression\":{\"operator\":{\"type\":\"RelationalOperator\",\"value\":\"<\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":10}}}}}},\"update\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"ComplexAssign\",\"value\":\"+=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}}}},\"body\":{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"ComplexAssign\",\"value\":\"+=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"y\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}}}}}}]}}}}]}");
    try testParserOutput("for(;;){}", "{\"body\":[{\"ForStatement\":{\"init\":null,\"testE\":null,\"update\":null,\"body\":{\"BlockStatement\":{\"body\":[]}}}}]}");
    try testParserOutput("for(x = 1;;){}", "{\"body\":[{\"ForStatement\":{\"init\":{\"Expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"SimpleAssign\",\"value\":\"=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}}}}},\"testE\":null,\"update\":null,\"body\":{\"BlockStatement\":{\"body\":[]}}}}]}");
}

test "Function Declaration" {
    try testParserOutput("def test(x,y){x += 1; return x;}", "{\"body\":[{\"FunctionDeclaration\":{\"name\":{\"name\":\"test\"},\"params\":[{\"name\":\"x\"},{\"name\":\"y\"}],\"body\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"AssignmentExpression\":{\"operator\":{\"type\":\"ComplexAssign\",\"value\":\"+=\"},\"left\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}}}}}},{\"ReturnStatement\":{\"argument\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"x\"}}}}}]}}}]}");
    try testParserOutput("def test(){return;}", "{\"body\":[{\"FunctionDeclaration\":{\"name\":{\"name\":\"test\"},\"params\":[],\"body\":{\"body\":[{\"ReturnStatement\":{\"argument\":null}}]}}}]}");
}

test "Member Expression" {
    try testParserOutput("a.b;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"MemberExpression\":{\"computed\":false,\"object\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"a\"}}},\"property\":{\"Identifier\":{\"name\":\"b\"}}}}}}]}");
    try testParserOutput("a.b.c[1+2];", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"MemberExpression\":{\"computed\":true,\"object\":{\"MemberExpression\":{\"computed\":false,\"object\":{\"MemberExpression\":{\"computed\":false,\"object\":{\"PrimaryExpression\":{\"Identifier\":{\"name\":\"a\"}}},\"property\":{\"Identifier\":{\"name\":\"b\"}}}},\"property\":{\"Identifier\":{\"name\":\"c\"}}}},\"property\":{\"Expression\":{\"BinaryExpression\":{\"operator\":{\"type\":\"AdditiveOperator\",\"value\":\"+\"},\"left\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":1}}}},\"right\":{\"PrimaryExpression\":{\"Literal\":{\"NumericLiteral\":{\"value\":2}}}}}}}}}}}]}");
}
