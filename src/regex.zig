const std = @import("std");
const c = @cImport({
    @cInclude("regex.h");
    @cInclude("regex_slim.h");
});

pub const Regex = struct {
    inner: *c.regex_t,

    pub const Error = error{ RegexCompileError, RegexCapturesError };

    pub fn init(pattern: []const u8) !Regex {
        const inner = c.alloc_regex_t().?;
        if (c.regcomp(inner, pattern, c.REG_NEWLINE | c.REG_EXTENDED) != 0) {
            return Error.RegexCompileError;
        }

        return .{ .inner = inner };
    }

    pub fn deinit(self: Regex) void {
        c.free_regex_t(self.inner);
    }

    pub fn matches(self: Regex, input: [:0]const u8) bool {
        const match_size = 1;
        var pmatch: [match_size]c.regmatch_t = undefined;
        return c.regexec(self.inner, input, match_size, &pmatch, 0) == 0;
    }

    pub fn exec(self: Regex, input: [:0]const u8) !?[:0]const u8 {
        const match_size = 1;
        var pmatch: [match_size]c.regmatch_t = undefined;

        if (c.regexec(self.inner, input, match_size, &pmatch, 0) == 0) {
            const start_offset = pmatch[0].rm_so;
            const end_offset = pmatch[0].rm_eo;
            const slice = input[@as(usize, @intCast(start_offset))..@as(usize, @intCast(end_offset))];

            return slice;
        }

        return null;
    }
};
