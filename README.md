# ZENV
A simple package for getting env from terminal or dotenv file (.env).

## Features
- [x] Read a key with parsed value. (int, slice)
- [x] Read a key with prefix. (.e.g "DB_", "APP_")
- [x] Serialize env to safety struct.
- [ ] Read env from a specififed file. (.e.g .env)          (In progress)

## Usage
- Read a key with type `T`:
```zig
test "read from terminal" {
    const allocator = std.testing.allocator;
    const env_reader: Self = try .init(allocator, .TERM, .{});
    defer env_reader.deinit();

    const slice = try env_reader.readKey([]const u8, .{}, "TEST_SLICE"); // string
    try expect(std.mem.eql(u8, slice.?[0..], "test"));
    try expect(@TypeOf(slice.?) == []const u8);

    const int = try env_reader.readKey(u8, .{}, "TEST_NUMBER");
    try expect(int.? == 0);
    try expect(@TypeOf(int.?) == u8);

    // Read with prefix
    const with_prefix = try env_reader.readKey([]const u8, .{ .prefix = "PREFIX_" }, "SLICE"); // string
    try expect(std.mem.eql(u8, with_prefix.?[0..], "prefix"));
    try expect(@TypeOf(slice.?) == []const u8);
}
```
- Read a struct:
```zig
test "read struct from terminal" {
    const allocator = std.testing.allocator;
    const env_reader: Self = try .init(allocator, .TERM, .{});
    defer env_reader.deinit();

    const Test = struct {
        value1: []const u8,
        value2: u8,
        value3: u16,
    };

    const struct_value = try env_reader.readStruct(Test, .{});
    try expect(std.mem.eql(u8, struct_value.value1, "value1"));
    try expect(struct_value.value2 == 2);
    try expect(struct_value.value3 == 3);

    // Read with prefix
    const Database = struct {
        port: u16,
        username: []const u8,
        password: []const u8,
    };

    const database_value = try env_reader.readStruct(Database, .{ .prefix = "DB_" });
    try expect(database_value.port == 5432);
    try expect(std.mem.eql(u8, database_value.username, "root_username"));
    try expect(std.mem.eql(u8, database_value.password, "root_password"));
}
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
