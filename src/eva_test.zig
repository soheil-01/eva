const std = @import("std");
const Parser = @import("parser.zig").Parser;
const Eva = @import("eva.zig").Eva;

// TODO: Using std.testing.allocator would cause a memory leak
const allocator = std.heap.page_allocator;

fn testEvaluationOutput(program: []const u8, expected: []const u8) !void {
    var parser = Parser.init(allocator);
    const ast = try parser.parse(program);

    var eva = try Eva.init(allocator);
    const result = try eva.evalProgram(ast);

    try std.testing.expectEqualStrings(expected, try result.toString(allocator));
}

test "Math" {
    try testEvaluationOutput("1 + 2 * 3 - 4 / 2;", "5");
}

test "Variables" {
    try testEvaluationOutput(
        \\ let x = 1;
        \\ x;
    , "1");

    try testEvaluationOutput(
        \\ let x = 1;
        \\{
        \\  let y = x + 2;
        \\  y;
        \\}
    , "3");

    try testEvaluationOutput(
        \\ let x = 1;
        \\ x = 2;
        \\ x;
    , "2");
}

test "Relational" {
    try testEvaluationOutput("3 > 2;", "true");
    try testEvaluationOutput("1 < 2;", "true");
    try testEvaluationOutput("2 > 4;", "false");
    try testEvaluationOutput("2 >= 2;", "true");
    try testEvaluationOutput("1 <= 1;", "true");
}

test "Equality" {
    try testEvaluationOutput("2 + 1 == 3;", "true");
    try testEvaluationOutput("2 + 3 != 1 + 4;", "false");
}

test "If" {
    try testEvaluationOutput(
        \\ let x = 1;
        \\ if(x < 2) {
        \\  x = x + 2;
        \\}
        \\
    , "3");

    try testEvaluationOutput(
        \\ let x = 2;
        \\ if(x < 2){}
        \\ else {
        \\  x = 10;
        \\}
    , "10");
}

test "While" {
    try testEvaluationOutput(
        \\ let i = 0;
        \\ while(i < 10){
        \\  i = i + 1;
        \\}
        \\ i;
    , "10");
}

test "Do While" {
    try testEvaluationOutput(
        \\ let i = 0;
        \\ do {
        \\  i = i + 1;
        \\} while(i < 1);
    , "1");
}

test "For" {
    try testEvaluationOutput(
        \\ let x = 0;
        \\ for(let i = 0; i < 10; i = i + 1){
        \\  x = x + 1;
        \\}
    , "10");
}

test "Unary" {
    try testEvaluationOutput("!(2 > 1);", "false");
}
