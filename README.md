# ZENV
A simple package for getting env from terminal or dotenv file (.env).

## Features
- [x] Read a key with parsed value. (int, a slice character)
- [x] Read a key with prefix. (.e.g "DB_", "APP_")
- [x] Serialize env to safety struct.
- [x] Read env from a specififed file. (.e.g .env)          
- [x] Custom reader (Create your own env reader from xml, json, ...)

## Quick Usage
- Read a key with type `T` from terminal:
```zig
    const allocator = std.testing.allocator;
    var term: Term = try .init(allocator);
    defer term.deinit();
    const reader = term.reader();

    const slice = try reader.readKey([]const u8, "TEST_SLICE", .{});
```
- Read a struct from terminal:
```zig
    const allocator = std.testing.allocator;
    var term: Term = try .init(allocator);
    defer term.deinit();
    const reader = term.reader();

    const Test = struct {
        value1: []const u8,
        value2: u8,
        value3: u16,
    };

    const struct_value = try reader.readStruct(Test, .{});
```
## Install
```shell
zig fetch --save https://github.com/zig-space/zenv#master
```
- Then add the dependency to `build.zig`:
```zig
const zenv = b.dependency("zenv", .{
    .target = target,
    .optimize = optimize,
}).module("zenv");
exe.root_module.addImport("zenv", zenv);
```
