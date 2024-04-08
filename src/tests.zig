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
    try testParserOutput("42;", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}]}");
    try testParserOutput("\"hello\";", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}]}");
    try testParserOutput("'hello';", "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}]}");
}

test "StatementList" {
    try testParserOutput(
        \\ "hello";
        \\ // Comment
        \\ 42;
    , "{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}},{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}}]}");
}

test "Block" {
    try testParserOutput("{42; 'hello';}", "{\"body\":[{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}},{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}]}}]}");
    try testParserOutput("{ }", "{\"body\":[{\"BlockStatement\":{\"body\":[]}}]}");
    try testParserOutput("{ 42; { 'hello'; } }", "{\"body\":[{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"NumericLiteral\":{\"value\":42}}}}},{\"BlockStatement\":{\"body\":[{\"ExpressionStatement\":{\"expression\":{\"Literal\":{\"StringLiteral\":{\"value\":\"hello\"}}}}}]}}]}}]}");
}

test "Empty Statement" {
    try testParserOutput(";", "{\"body\":[{\"EmptyStatement\":{}}]}");
}
