const std = @import("std");
const Eva = @import("eva.zig").Eva;
const Parser = @import("parser.zig").Parser;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var args = std.process.args();
    _ = args.next();

    var fileName: []const u8 = "";
    if (args.next()) |f| {
        fileName = f;
    }

    const file = try std.fs.cwd().openFile(fileName, .{});
    defer file.close();

    const fileSize = try file.getEndPos();
    const codes = try allocator.alloc(u8, fileSize);
    _ = try file.read(codes);

    var parser = try Parser.init(allocator);
    defer parser.deinit();

    const ast = try parser.parse(codes);

    var eva = try Eva.init(allocator);
    defer eva.deinit();

    const result = try eva.evalProgram(ast);
    try result.display(allocator);
}
