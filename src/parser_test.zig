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
    try testParserOutput("42;",
        \\{"body":[{"ExpressionStatement":{"expression":{"Literal":{"NumericLiteral":{"value":42}}}}}]}
    );
    try testParserOutput("\"hello\";",
        \\{"body":[{"ExpressionStatement":{"expression":{"Literal":{"StringLiteral":{"value":"hello"}}}}}]}
    );
    try testParserOutput("'hello';",
        \\{"body":[{"ExpressionStatement":{"expression":{"Literal":{"StringLiteral":{"value":"hello"}}}}}]}
    );
}

test "StatementList" {
    try testParserOutput(
        \\ "hello";
        \\ // Comment
        \\ 42;
    ,
        \\{"body":[{"ExpressionStatement":{"expression":{"Literal":{"StringLiteral":{"value":"hello"}}}}},{"ExpressionStatement":{"expression":{"Literal":{"NumericLiteral":{"value":42}}}}}]}
    );
}

test "Block" {
    try testParserOutput("{42; 'hello';}",
        \\{"body":[{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"Literal":{"NumericLiteral":{"value":42}}}}},{"ExpressionStatement":{"expression":{"Literal":{"StringLiteral":{"value":"hello"}}}}}]}}]}
    );
    try testParserOutput("{ }",
        \\{"body":[{"BlockStatement":{"body":[]}}]}
    );
    try testParserOutput("{ 42; { 'hello'; } }",
        \\{"body":[{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"Literal":{"NumericLiteral":{"value":42}}}}},{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"Literal":{"StringLiteral":{"value":"hello"}}}}}]}}]}}]}
    );
}

test "Empty Statement" {
    try testParserOutput(";",
        \\{"body":[{"EmptyStatement":{}}]}
    );
}

test "Math" {
    try testParserOutput("42 + 43;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"Literal":{"NumericLiteral":{"value":42}}},"right":{"Literal":{"NumericLiteral":{"value":43}}}}}}}]}
    );
    try testParserOutput("42 - 43 + 44;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"-"},"left":{"Literal":{"NumericLiteral":{"value":42}}},"right":{"Literal":{"NumericLiteral":{"value":43}}}}},"right":{"Literal":{"NumericLiteral":{"value":44}}}}}}}]}
    );
    try testParserOutput("42 * 43;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"MultiplicativeOperator","value":"*"},"left":{"Literal":{"NumericLiteral":{"value":42}}},"right":{"Literal":{"NumericLiteral":{"value":43}}}}}}}]}
    );
    try testParserOutput("42 + 43 * 44;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"Literal":{"NumericLiteral":{"value":42}}},"right":{"BinaryExpression":{"operator":{"type":"MultiplicativeOperator","value":"*"},"left":{"Literal":{"NumericLiteral":{"value":43}}},"right":{"Literal":{"NumericLiteral":{"value":44}}}}}}}}}]}
    );
    try testParserOutput("(42 + 43) * 44;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"MultiplicativeOperator","value":"*"},"left":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"Literal":{"NumericLiteral":{"value":42}}},"right":{"Literal":{"NumericLiteral":{"value":43}}}}},"right":{"Literal":{"NumericLiteral":{"value":44}}}}}}}]}
    );
}

test "Assignment" {
    try testParserOutput("x = 42;",
        \\{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":42}}}}}}}]}
    );
    try testParserOutput("x = y = 42;",
        \\{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"Identifier":{"name":"x"}},"right":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"Identifier":{"name":"y"}},"right":{"Literal":{"NumericLiteral":{"value":42}}}}}}}}}]}
    );
    try testParserOutput("x += 2;",
        \\{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"ComplexAssign","value":"+="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":2}}}}}}}]}
    );
}

test "Variable" {
    try testParserOutput("let x = 42;",
        \\{"body":[{"VariableStatement":{"declarations":[{"id":{"name":"x"},"init":{"Literal":{"NumericLiteral":{"value":42}}}}]}}]}
    );
    try testParserOutput("let x;",
        \\{"body":[{"VariableStatement":{"declarations":[{"id":{"name":"x"},"init":null}]}}]}
    );
    try testParserOutput("let x,y=10;",
        \\{"body":[{"VariableStatement":{"declarations":[{"id":{"name":"x"},"init":null},{"id":{"name":"y"},"init":{"Literal":{"NumericLiteral":{"value":10}}}}]}}]}
    );
}

test "If" {
    try testParserOutput("if(x){x = 42;}else{x = 43;}",
        \\{"body":[{"IfStatement":{"testE":{"Identifier":{"name":"x"}},"consequent":{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":42}}}}}}}]}},"alternate":{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":43}}}}}}}]}}}}]}
    );
    try testParserOutput("if(x){x = 42;}",
        \\{"body":[{"IfStatement":{"testE":{"Identifier":{"name":"x"}},"consequent":{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":42}}}}}}}]}},"alternate":null}}]}
    );
}

test "Relational" {
    try testParserOutput("x + 2 > 3;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":">"},"left":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":2}}}}},"right":{"Literal":{"NumericLiteral":{"value":3}}}}}}}]}
    );
    try testParserOutput("let y = x + 2 > 3;",
        \\{"body":[{"VariableStatement":{"declarations":[{"id":{"name":"y"},"init":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":">"},"left":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":2}}}}},"right":{"Literal":{"NumericLiteral":{"value":3}}}}}}]}}]}
    );
}

test "Equality" {
    try testParserOutput("x == 2;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"EqualityOperator","value":"=="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":2}}}}}}}]}
    );
    try testParserOutput("x > 2 == true;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"EqualityOperator","value":"=="},"left":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":">"},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":2}}}}},"right":{"Literal":{"BooleanLiteral":{"value":true}}}}}}}]}
    );
    try testParserOutput("x != false;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"EqualityOperator","value":"!="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"BooleanLiteral":{"value":false}}}}}}}]}
    );
    try testParserOutput("x != null;",
        \\{"body":[{"ExpressionStatement":{"expression":{"BinaryExpression":{"operator":{"type":"EqualityOperator","value":"!="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NullLiteral":{}}}}}}}]}
    );
}

test "Logical" {
    try testParserOutput("x > 1 && y < 2 || z > 3;",
        \\{"body":[{"ExpressionStatement":{"expression":{"LogicalExpression":{"operator":{"type":"LogicalOr","value":"||"},"left":{"LogicalExpression":{"operator":{"type":"LogicalAnd","value":"&&"},"left":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":">"},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":1}}}}},"right":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":"<"},"left":{"Identifier":{"name":"y"}},"right":{"Literal":{"NumericLiteral":{"value":2}}}}}}},"right":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":">"},"left":{"Identifier":{"name":"z"}},"right":{"Literal":{"NumericLiteral":{"value":3}}}}}}}}}]}
    );
}

test "Unary" {
    try testParserOutput("!x;",
        \\{"body":[{"ExpressionStatement":{"expression":{"UnaryExpression":{"operator":{"type":"LogicalNot","value":"!"},"argument":{"Identifier":{"name":"x"}}}}}}]}
    );
    try testParserOutput("-+x;",
        \\{"body":[{"ExpressionStatement":{"expression":{"UnaryExpression":{"operator":{"type":"AdditiveOperator","value":"-"},"argument":{"UnaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"argument":{"Identifier":{"name":"x"}}}}}}}}]}
    );
}

test "While" {
    try testParserOutput("while(x<10){x += 1;}",
        \\{"body":[{"WhileStatement":{"testE":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":"<"},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":10}}}}},"body":{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"ComplexAssign","value":"+="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":1}}}}}}}]}}}}]}
    );
}

test "Do While" {
    try testParserOutput("do{x += 1;}while(x<10);",
        \\{"body":[{"DoWhileStatement":{"testE":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":"<"},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":10}}}}},"body":{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"ComplexAssign","value":"+="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":1}}}}}}}]}}}}]}
    );
}

test "For" {
    try testParserOutput("for(let x=1;x<10;x+=1){y+=1;}",
        \\{"body":[{"ForStatement":{"init":{"VariableStatement":{"declarations":[{"id":{"name":"x"},"init":{"Literal":{"NumericLiteral":{"value":1}}}}]}},"testE":{"BinaryExpression":{"operator":{"type":"RelationalOperator","value":"<"},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":10}}}}},"update":{"AssignmentExpression":{"operator":{"type":"ComplexAssign","value":"+="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":1}}}}},"body":{"BlockStatement":{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"ComplexAssign","value":"+="},"left":{"Identifier":{"name":"y"}},"right":{"Literal":{"NumericLiteral":{"value":1}}}}}}}]}}}}]}
    );
    try testParserOutput("for(;;){}",
        \\{"body":[{"ForStatement":{"init":null,"testE":null,"update":null,"body":{"BlockStatement":{"body":[]}}}}]}
    );
    try testParserOutput("for(x = 1;;){}",
        \\{"body":[{"ForStatement":{"init":{"Expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":1}}}}}},"testE":null,"update":null,"body":{"BlockStatement":{"body":[]}}}}]}
    );
}

test "Function Declaration" {
    try testParserOutput("def test(x,y){x += 1; return x;}",
        \\{"body":[{"FunctionDeclaration":{"name":{"name":"test"},"params":[{"name":"x"},{"name":"y"}],"body":{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"ComplexAssign","value":"+="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":1}}}}}}},{"ReturnStatement":{"argument":{"Identifier":{"name":"x"}}}}]}}}]}
    );
    try testParserOutput("def test(){return;}",
        \\{"body":[{"FunctionDeclaration":{"name":{"name":"test"},"params":[],"body":{"body":[{"ReturnStatement":{"argument":null}}]}}}]}
    );
}

test "Member Expression" {
    try testParserOutput("a.b;",
        \\{"body":[{"ExpressionStatement":{"expression":{"MemberExpression":{"computed":false,"object":{"Identifier":{"name":"a"}},"property":{"Identifier":{"name":"b"}}}}}}]}
    );
    try testParserOutput("a.b.c[1+2];",
        \\{"body":[{"ExpressionStatement":{"expression":{"MemberExpression":{"computed":true,"object":{"MemberExpression":{"computed":false,"object":{"MemberExpression":{"computed":false,"object":{"Identifier":{"name":"a"}},"property":{"Identifier":{"name":"b"}}}},"property":{"Identifier":{"name":"c"}}}},"property":{"Expression":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"Literal":{"NumericLiteral":{"value":1}}},"right":{"Literal":{"NumericLiteral":{"value":2}}}}}}}}}}]}
    );
}

test "Call Expression" {
    try testParserOutput("a(x = 1,y);",
        \\{"body":[{"ExpressionStatement":{"expression":{"CallExpression":{"callee":{"Identifier":{"name":"a"}},"arguments":[{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"Identifier":{"name":"x"}},"right":{"Literal":{"NumericLiteral":{"value":1}}}}},{"Identifier":{"name":"y"}}]}}}}]}
    );
    try testParserOutput("a(x)(y);",
        \\{"body":[{"ExpressionStatement":{"expression":{"CallExpression":{"callee":{"CallExpression":{"callee":{"Identifier":{"name":"a"}},"arguments":[{"Identifier":{"name":"x"}}]}},"arguments":[{"Identifier":{"name":"y"}}]}}}}]}
    );
}

test "Class" {
    try testParserOutput(
        \\ class Point {
        \\  def constructor(x, y){
        \\  this.x = x;
        \\  this.y = y;
        \\}
        \\  def calc(){
        \\  return this.x + this.y;
        \\}
        \\}
    ,
        \\{"body":[{"ClassDeclaration":{"id":{"name":"Point"},"superClass":null,"body":{"body":[{"FunctionDeclaration":{"name":{"name":"constructor"},"params":[{"name":"x"},{"name":"y"}],"body":{"body":[{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"MemberExpression":{"computed":false,"object":{"ThisExpression":{}},"property":{"Identifier":{"name":"x"}}}},"right":{"Identifier":{"name":"x"}}}}}},{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"MemberExpression":{"computed":false,"object":{"ThisExpression":{}},"property":{"Identifier":{"name":"y"}}}},"right":{"Identifier":{"name":"y"}}}}}}]}}},{"FunctionDeclaration":{"name":{"name":"calc"},"params":[],"body":{"body":[{"ReturnStatement":{"argument":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"MemberExpression":{"computed":false,"object":{"ThisExpression":{}},"property":{"Identifier":{"name":"x"}}}},"right":{"MemberExpression":{"computed":false,"object":{"ThisExpression":{}},"property":{"Identifier":{"name":"y"}}}}}}}}]}}}]}}}]}
    );
    try testParserOutput(
        \\ class Point3D extends Point {
        \\  def constructor(x,y,z){
        \\  super(x,y);
        \\  this.z = z;
        \\}
        \\  def calc(){
        \\  return super() + this.z;
        \\}
        \\}
    ,
        \\{"body":[{"ClassDeclaration":{"id":{"name":"Point3D"},"superClass":{"name":"Point"},"body":{"body":[{"FunctionDeclaration":{"name":{"name":"constructor"},"params":[{"name":"x"},{"name":"y"},{"name":"z"}],"body":{"body":[{"ExpressionStatement":{"expression":{"CallExpression":{"callee":{"Super":{}},"arguments":[{"Identifier":{"name":"x"}},{"Identifier":{"name":"y"}}]}}}},{"ExpressionStatement":{"expression":{"AssignmentExpression":{"operator":{"type":"SimpleAssign","value":"="},"left":{"MemberExpression":{"computed":false,"object":{"ThisExpression":{}},"property":{"Identifier":{"name":"z"}}}},"right":{"Identifier":{"name":"z"}}}}}}]}}},{"FunctionDeclaration":{"name":{"name":"calc"},"params":[],"body":{"body":[{"ReturnStatement":{"argument":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"CallExpression":{"callee":{"Super":{}},"arguments":[]}},"right":{"MemberExpression":{"computed":false,"object":{"ThisExpression":{}},"property":{"Identifier":{"name":"z"}}}}}}}}]}}}]}}}]}
    );

    try testParserOutput(
        \\let p = new Point3D(10,20,30);
        \\p.calc();
    ,
        \\{"body":[{"VariableStatement":{"declarations":[{"id":{"name":"p"},"init":{"NewExpression":{"callee":{"Identifier":{"name":"Point3D"}},"arguments":[{"Literal":{"NumericLiteral":{"value":10}}},{"Literal":{"NumericLiteral":{"value":20}}},{"Literal":{"NumericLiteral":{"value":30}}}]}}}]}},{"ExpressionStatement":{"expression":{"CallExpression":{"callee":{"MemberExpression":{"computed":false,"object":{"Identifier":{"name":"p"}},"property":{"Identifier":{"name":"calc"}}}},"arguments":[]}}}}]}
    );
}

test "Lambda" {
    try testParserOutput("let func = lambda (x,y) x+y;",
        \\{"body":[{"VariableStatement":{"declarations":[{"id":{"name":"func"},"init":{"LambdaExpression":{"params":[{"name":"x"},{"name":"y"}],"body":{"Expression":{"BinaryExpression":{"operator":{"type":"AdditiveOperator","value":"+"},"left":{"Identifier":{"name":"x"}},"right":{"Identifier":{"name":"y"}}}}}}}}]}}]}
    );

    try testParserOutput("let func = lambda () {return 10;};",
        \\{"body":[{"VariableStatement":{"declarations":[{"id":{"name":"func"},"init":{"LambdaExpression":{"params":[],"body":{"BlockStatement":{"body":[{"ReturnStatement":{"argument":{"Literal":{"NumericLiteral":{"value":10}}}}}]}}}}}]}}]}
    );
}
