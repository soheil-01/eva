# Zig RDP

Recursive Descent Parser in Zig, based on [Building a Parser from scratch](https://www.udemy.com/course/parser-from-scratch/).

## Dependencies

- [zig-regex](https://github.com/tiehuis/zig-regex)

## Run

```bash
zig build run -- tests/basic.zz
```

## Installation

1. Declare zig-rdp as a project dependency with `zig fetch`:

```bash
zig fetch --save git+https://github.com/soheil-01/zig-rdp.git#main
```

2. Expose zig-rdp as a module in your project's `build.zig`:

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const opts = .{ .target = target, .optimize = optimize };      // 👈
    const rdp_mod = b.dependency("zig-rdp", opts).module("zig-rdp"); // 👈

    const exe = b.addExecutable(.{
        .name = "my-project",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zig-rdp", rdp_mod); // 👈

    // ...
}
```

3. Import zig-rdp into your code:

```zig
const Parser = @import("zig-rdp").Parser;
```
