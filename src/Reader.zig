//! The env reader.
//! # Features
//! - Read from the `terminal` or a specified `file`
//! depends on the `Zenv.from` field.
const std = @import("std");
const Self = @This();

allocator: std.mem.Allocator,
arena: *std.heap.ArenaAllocator,
/// Specified that the reader will read
/// from the `terminal` or a specified `file`.
///
/// If `file` is used, the path to that file will
/// be specified in the `env_file_path` field.
///
/// **Default** is `From.FILE`.
from: From = .TERM,
/// The path file contains env (.e.g .env).
/// Is null if `Zenv.from` is `EnvFrom.TERM`.
///
///
/// Must be specified if `Zenv.from` is `EnvFrom.FILE`
/// .e.g ("path-to-your-project/.env")
///
/// **Default** is `null`.
env_file_path: ?[]const u8 = null,
opts: ReaderOptions,

pub const ReaderOptions = struct {
    /// The reader prefix the key for reading
    ///
    /// **Default** is `null`
    prefix: ?[]const u8 = null,
    /// Remove whitespace at the beginning and end of the value.
    /// Set `false` if disable.
    ///
    /// **Default** is `true`
    trim: bool = true,
};

const ReaderError = error{ EmptyFilePath, NotSupportedType, MissingField };

const From = enum {
    TERM,
    // TODO:
    // FILE,
};

/// The caller should call `deinit()` after finish.
pub fn init(allocator: std.mem.Allocator, from: From, opts: ReaderOptions) !Self {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = std.heap.ArenaAllocator.init(allocator);
    return .{
        .allocator = allocator,
        .arena = arena,
        .from = from,
        .opts = opts,
    };
}
pub fn deinit(self: Self) void {
    self.arena.deinit();
    self.allocator.destroy(self.arena);
}

pub fn readStruct(self: Self, comptime T: type, comptime opts: ReaderOptions) !*const T {
    if (@typeInfo(T) != .@"struct") {
        @compileError(std.fmt.comptimePrint("Expected a `struct` found {s}\n", @typeName(@typeInfo(T))));
    }
    const allocator = self.arena.allocator();

    const @"struct" = try allocator.create(T);
    inline for (@typeInfo(T).@"struct".fields) |field| {
        var buffer: [field.name.len]u8 = undefined;
        _ = std.ascii.upperString(buffer[0..], field.name);
        const value = try self.readKey(field.type, opts, buffer[0..]) orelse {
            std.log.scoped(.zenv).err("Not found environment {s} in struct {s}\n", .{ buffer, @typeName(T) });
            return ReaderError.MissingField;
        };

        @field(@"struct", field.name) = value;
    }
    return @"struct";
}
/// Return a value with `T` type.
pub fn readKey(self: Self, comptime T: type, opts: ReaderOptions, key: []const u8) !?T {
    const prefix_key = try std.fmt.allocPrint(self.arena.allocator(), "{s}{s}", .{ opts.prefix orelse "", key });
    return switch (self.from) {
        .TERM => try self.readKeyFromTerm(T, prefix_key[0..]),
    };
}

// TODO:
// pub fn readKeyFromFile(self: Self, comptime T: type, comptime key: []const u8) !T {
//     std.debug.assert(self.from == .FILE);
//     if (self.env_file_path == null) {
//         std.log.warn("`Reader.env_file_path cannot be null when using From.File`", .{});
//         return ReaderError.EmptyFilePath;
//     }
// }

pub fn readKeyFromTerm(self: Self, comptime T: type, key: []const u8) !?T {
    std.debug.assert(self.from == .TERM);
    const env = std.process.getEnvVarOwned(self.arena.allocator(), key[0..]) catch |err| switch (err) {
        std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound => return null,
        else => return err,
    };
    defer self.arena.allocator().free(env);
    return try self.parse(T, env);
}

pub fn parse(self: Self, comptime T: type, value: []const u8) !T {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => {
            return try std.fmt.parseInt(T, value, 10);
        },
        .pointer => |pointerInfo| {
            if (pointerInfo.child == u8) {
                var trimmed = value[0..];
                if (self.opts.trim) {
                    trimmed = std.mem.trim(u8, value[0..], " ");
                }
                const new_buffer = try self.arena.allocator().alloc(u8, trimmed.len);
                @memcpy(new_buffer[0..], trimmed[0..]);
                return new_buffer[0..];
            } else {
                std.log.scoped(.zenv).err("Not supported type: {s}\n", .{@typeName(T)});
                return ReaderError.NotSupportedType;
            }
        },
        else => {
            std.log.scoped(.zenv).err("Not supported type: {s}\n", .{@typeName(T)});
            return ReaderError.NotSupportedType;
        },
    };
}

const expect = std.testing.expect;
const expectError = std.testing.expectError;
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

    const with_prefix = try env_reader.readKey([]const u8, .{ .prefix = "PREFIX_" }, "SLICE"); // string
    try expect(std.mem.eql(u8, with_prefix.?[0..], "prefix"));
    try expect(@TypeOf(slice.?) == []const u8);
}

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

    const Database = struct {
        port: u16,
        username: []const u8,
        password: []const u8,
    };

    const database_value = try env_reader.readStruct(Database, .{ .prefix = "DB_" });
    try expect(database_value.port == 5432);
    try expect(std.mem.eql(u8, database_value.username, "root_username"));
    try expect(std.mem.eql(u8, database_value.password, "root_password"));

    const MissingField = struct {
        field: u8,
    };
    try expectError(ReaderError.MissingField, env_reader.readStruct(MissingField, .{}));

    const NotSupportedType = struct {
        not_supported_type: bool,
    };
    try expectError(ReaderError.NotSupportedType, env_reader.readStruct(NotSupportedType, .{}));
}
