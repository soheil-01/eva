const std = @import("std");
const Eva = @import("eva.zig").Eva;
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var parser = Parser.init(allocator);
    const ast = try parser.parse(
        \\{
        \\ let x = 1;
        \\ x = 3;
        \\{
        \\  let x = 4;
        \\  x;
        \\}
        \\ x;
        \\}
    );
    const statement = ast.body[0];

    var eva = try Eva.init(allocator);
    const result = try eva.eval(statement, &eva.global);

    eva.displayResult(result);

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
