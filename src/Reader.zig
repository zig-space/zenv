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
opts: ReaderOptions,

pub const ReaderOptions = struct {
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
};

const ReaderError = error{ EmptyFilePath, NotSupportedType };

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

pub fn readStruct(self: Self, comptime T: type) !*const T {
    if (@typeInfo(T) != .@"struct") {
        @compileError(std.fmt.comptimePrint("Expected a `struct` found {s}\n", @typeName(@typeInfo(T))));
    }
    const allocator = self.arena.allocator();

    const @"struct" = try allocator.create(T);
    inline for (@typeInfo(T).@"struct".fields) |field| {
        var buffer: [field.name.len]u8 = undefined;
        _ = std.ascii.upperString(buffer[0..], field.name);
        const value = try self.readKey(field.type, buffer[0..]) orelse {
            std.log.warn("Not found environment: {s}", .{buffer});
            return std.process.GetEnvVarOwnedError.EnvironmentVariableNotFound;
        };

        @field(@"struct", field.name) = value;
    }
    return @"struct";
}
/// Return a value with `T` type.
pub fn readKey(self: Self, comptime T: type, key: []const u8) !?T {
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
    const env_reader: Self = try .init(allocator, .TERM, .{});
    defer env_reader.deinit();

    const slice = try env_reader.readKey([]const u8, "TEST_SLICE"); // string
    try expect(std.mem.eql(u8, slice.?[0..], "test"));
    try expect(@TypeOf(slice.?) == []const u8);

    const int = try env_reader.readKey(u8, "TEST_NUMBER");
    try expect(int.? == 0);
    try expect(@TypeOf(int.?) == u8);
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

    const struct_value = try env_reader.readStruct(Test);
    try expect(std.mem.eql(u8, struct_value.value1, "value1"));
    try expect(struct_value.value2 == 2);
    try expect(struct_value.value3 == 3);
}
