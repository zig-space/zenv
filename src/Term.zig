const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const Reader = @import("Reader.zig");
const Opts = Reader.Options;
const Self = @This();

allocator: std.mem.Allocator,
_arena: *std.heap.ArenaAllocator,

pub fn init(alloc: Allocator) !Self {
    const arena = try alloc.create(ArenaAllocator);
    arena.* = ArenaAllocator.init(alloc);
    return .{
        .allocator = arena.allocator(),
        ._arena = arena,
    };
}
pub fn reader(self: *const Self) Reader {
    return .{
        .allocator = self.allocator,
        .ptr = @constCast(self),
        .vtable = .{ .readFn = read },
    };
}

pub fn deinit(self: *Self) void {
    const alloc = self._arena.child_allocator;
    self._arena.deinit();
    alloc.destroy(self._arena);
}

pub fn read(ctx: *const anyopaque, key: []const u8) !?[]const u8 {
    const self: *const Self = @ptrCast(@alignCast(ctx));
    defer self.allocator.free(key);

    return std.process.getEnvVarOwned(self.allocator, key) catch |err| switch (err) {
        std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound => return null,
        else => return err,
    };
}

const expect = std.testing.expect;
const expectError = std.testing.expectError;
test "read a key from terminal" {
    const allocator = std.testing.allocator;
    var env_reader: Self = try .init(allocator);
    defer env_reader.deinit();
    const t_reader = env_reader.reader();

    const slice = try t_reader.readKey([]const u8, "TEST_SLICE", .{}); // string
    try expect(std.mem.eql(u8, slice.?[0..], "test"));
    try expect(@TypeOf(slice.?) == []const u8);

    const int = try t_reader.readKey(u8, "TEST_NUMBER", .{});
    try expect(int.? == 0);
    try expect(@TypeOf(int.?) == u8);

    const with_prefix = try t_reader.readKey([]const u8, "SLICE", .{ .prefix = "PREFIX_" }); // string
    try expect(std.mem.eql(u8, with_prefix.?[0..], "prefix"));
    try expect(@TypeOf(slice.?) == []const u8);
}

test "Read a struct from terminal" {
    const allocator = std.testing.allocator;
    var env_reader: Self = try .init(allocator);
    defer env_reader.deinit();
    const t_reader = env_reader.reader();

    const Test = struct {
        value1: []const u8,
        value2: u8,
        value3: u16,
    };

    const struct_value = try t_reader.readStruct(Test, .{});
    try expect(std.mem.eql(u8, struct_value.value1, "value1"));
    try expect(struct_value.value2 == 2);
    try expect(struct_value.value3 == 3);

    const Database = struct {
        port: u16,
        username: []const u8,
        password: []const u8,
    };

    const database_value = try t_reader.readStruct(Database, .{ .prefix = "DB_" });
    try expect(database_value.port == 5432);
    try expect(std.mem.eql(u8, database_value.username, "root_username"));
    try expect(std.mem.eql(u8, database_value.password, "root_password"));

    const MissingField = struct {
        field: u8,
    };
    try expectError(error.MissingField, t_reader.readStruct(MissingField, .{}));

    const NotSupportedType = struct {
        not_supported_type: bool,
    };
    try expectError(error.NotSupportedType, t_reader.readStruct(NotSupportedType, .{}));
}
