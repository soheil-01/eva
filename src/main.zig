const std = @import("std");
const Eva = @import("eva.zig").Eva;
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator);
    const ast = try parser.parse(
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
    );

    var eva = try Eva.init(allocator);
    const result = try eva.evalProgram(ast);
    try result.display(allocator);

    // var args = std.process.args();
    // _ = args.next();

    // var fileName: []const u8 = "";
    // if (args.next()) |f| {
    //     fileName = f;
    // }

    // const file = try std.fs.cwd().openFile(fileName, .{});
    // defer file.close();

    // const fileSize = try file.getEndPos();
    // const codes = try allocator.alloc(u8, fileSize);
    // _ = try file.read(codes);

    // var parser = Parser.init(allocator);
    // const ast = try parser.parse(codes);

    // const string = try std.json.stringifyAlloc(allocator, ast, .{});
    // std.debug.print("{s}\n", .{string});
}
