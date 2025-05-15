//! The env reader.
//! # Features
//! - Read from the `terminal` or a specified `file`
//! depends on the `Zenv.from` field.
const std = @import("std");
const Self = @This();

allocator: std.mem.Allocator,
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
/// Remove whitespace at the beginning and end of the value.
/// Set `false` if disable.
///
/// **Default** is `true`
trim: bool = true,

const ReaderError = error{ EmptyFilePath, NotSupportedType };

const From = enum {
    TERM,
    // TODO:
    // FILE,
};

/// Return a value with `T` type.
pub fn readKey(self: Self, comptime T: type, comptime key: []const u8) !T {
    return switch (self.from) {
        .TERM => try self.readKeyFromTerm(T, key[0..]),
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

pub fn readKeyFromTerm(self: Self, comptime T: type, comptime key: []const u8) !T {
    std.debug.assert(self.from == .TERM);
    const env = try std.process.getEnvVarOwned(self.allocator, key[0..]);
    errdefer self.allocator.free(env);
    return try self.parse(T, env);
}

pub fn parse(self: Self, comptime T: type, value: []const u8) !T {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => {
            const parsed = try std.fmt.parseInt(T, value, 10);
            self.allocator.free(value);
            return parsed;
        },
        .pointer => |pointerInfo| {
            if (pointerInfo.child == u8) {
                var trimmed = value[0..];
                if (self.trim) {
                    trimmed = std.mem.trim(u8, value[0..], " ");
                }
                return trimmed[0..];
            } else {
                std.log.warn("Not supported type: {s}", .{@typeName(T)});
                return ReaderError.NotSupportedType;
            }
        },
        else => {
            std.log.warn("Not supported type: {s}", .{@typeName(T)});
            return ReaderError.NotSupportedType;
        },
    };
}

const expect = std.testing.expect;
const expectError = std.testing.expectError;
test "read from terminal" {
    const allocator = std.testing.allocator;
    const env_reader: Self = .{
        .from = .TERM,
        .allocator = allocator,
    };
    const slice = try env_reader.readKey([]const u8, "TEST_SLICE"); // string
    defer allocator.free(slice);
    try expect(std.mem.eql(u8, slice[0..], "test"));
    try expect(@TypeOf(slice) == []const u8);

    const int = try env_reader.readKey(u8, "TEST_NUMBER");
    try expect(int == 0);
    try expect(@TypeOf(int) == u8);
}
