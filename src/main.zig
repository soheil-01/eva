const std = @import("std");
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var parser = Parser.init(allocator);
    const ast = try parser.parse("x > 1 && y < 2 || z > 3;");

    const string = try std.json.stringifyAlloc(allocator, ast, .{});
    std.debug.print("{s}\n", .{string});
}
