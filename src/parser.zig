const std = @import("std");

pub const Parser = struct {
    string: []const u8 = "",

    const ASTNode = union(enum) { numeric_literal: u64 };

    // Parse a string into an AST.
    fn parse(self: *Parser, string: []const u8) !ASTNode {
        self.string = string;

        return self.program();
    }

    // Main entry point.
    // Program
    //  : NumericLiteral
    //  ;
    fn program(self: *Parser) !ASTNode {
        return self.numericLiteral();
    }

    // NumericLiteral
    // : NUMBER
    // ;
    fn numericLiteral(self: *Parser) !ASTNode {
        const value = try std.fmt.parseUnsigned(u64, self.string, 10);
        return ASTNode{ .numeric_literal = value };
    }
};

test "Parser" {
    const allocator = std.testing.allocator;
    var parser = Parser{};
    const ast = try parser.parse("42");
    const json = try std.json.stringifyAlloc(allocator, ast, .{});
    defer allocator.free(json);
    std.debug.print("{s}\n", .{json});
}
