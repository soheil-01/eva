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

test "Function" {
    try testEvaluationOutput(
        \\ let value = 100;
        \\ def calc(x, y){
        \\   let z = x + y;
        \\   def inner(foo){
        \\   return foo + z + value;
        \\}
        \\  return inner;
        \\}
        \\let fn = calc(10, 20);
        \\fn(30);
    , "160");
}

test "Lambda" {
    try testEvaluationOutput(
        \\ def onClick(callback) {
        \\ let x = 10;
        \\ let y = 20;
        \\ return callback(x+y);
        \\}
        \\ onClick(lambda (data) data * 10);
    , "300");

    // IILE
    try testEvaluationOutput("(lambda (x) x * 2)(2);", "4");

    // Save lambda to a variable
    try testEvaluationOutput(
        \\ let square = lambda (x) x * x;
        \\ square(4);
    , "16");
}

test "Recursive function" {
    try testEvaluationOutput(
        \\ def fact(num) {
        \\  if(num == 1) { return 1; }
        \\  return num * fact(num - 1);
        \\}
        \\ fact(5);
    , "120");
}

test "Switch" {
    try testEvaluationOutput(
        \\ let x = 10;
        \\ let answer = "";
        \\ switch(x){
        \\ case 10 {
        \\  answer = "x is 10";
        \\}
        \\ case 20 {
        \\ answer = "x is 20";
        \\}
        \\ default {
        \\ answer = "x is neither 10 nor 20";
        \\}
        \\}
        \\answer;
    , "x is 10");

    try testEvaluationOutput(
        \\ let x = 20;
        \\ let answer = "";
        \\ switch(x){
        \\ case 10 {
        \\  answer = "x is 10";
        \\}
        \\ case 20 {
        \\ answer = "x is 20";
        \\}
        \\ default {
        \\ answer = "x is neither 10 nor 20";
        \\}
        \\}
        \\answer;
    , "x is 20");

    try testEvaluationOutput(
        \\ let x = 30;
        \\ let answer = "";
        \\ switch(x){
        \\ case 10 {
        \\  answer = "x is 10";
        \\}
        \\ case 20 {
        \\ answer = "x is 20";
        \\}
        \\ default {
        \\ answer = "x is neither 10 nor 20";
        \\}
        \\}
        \\answer;
    , "x is neither 10 nor 20");
}

test "Class" {
    try testEvaluationOutput(
        \\ class Point {
        \\  def constructor(self, x, y){
        \\  self.x = x;
        \\  self.y = y;
        \\}
        \\  def calc(self){
        \\  return self.x + self.y;
        \\}
        \\}
        \\ let p = new Point(10,20);
        \\ p.calc(p);
    , "30");

    try testEvaluationOutput(
        \\ class Point {
        \\  def constructor(self, x, y){
        \\  self.x = x;
        \\  self.y = y;
        \\}
        \\  def calc(self){
        \\  return self.x + self.y;
        \\}
        \\}
        \\
        \\ class Point3D extends Point {
        \\  def constructor(self, x, y, z){
        \\  super(Point3D).constructor(self, x, y);
        \\  self.z = z;
        \\}
        \\  def calc(self){
        \\  return super(Point3D).calc(self) + self.z;
        \\}
        \\}
        \\ let p = new Point3D(10, 20, 30);
        \\ p.calc(p);
    , "60");
}
