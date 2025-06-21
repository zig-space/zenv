//! The standard env reader interface for `zenv`.
const std = @import("std");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

const Self = @This();

allocator: std.mem.Allocator,
ptr: *anyopaque,
vtable: VTable,

pub const Options = struct {
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

pub const VTable = struct {
    /// An `abstract function` with return raw value (`[]const u8`) when reading.
    readFn: *const fn (*const anyopaque, key: []const u8) anyerror!?[]const u8,
};

/// - Read a `key` and return value with `T` type.
/// - opts.prefix will be used if not null.
/// - Letters is uppercase. (key -> KEY)
///
/// Currently, this function only support these types:
/// * *builtin.Int* (i8, u8, i16, i16, ...)
/// * *[]const u8* or *[]u8*
pub fn readKey(self: Self, comptime T: type, key: []const u8, opts: Options) !?T {
    const prefix_key = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ opts.prefix orelse "", key });
    defer self.allocator.free(prefix_key);
    const upper = try std.ascii.allocUpperString(self.allocator, prefix_key);
    const raw_value = try self.vtable.readFn(self.ptr, upper) orelse return null;
    defer self.allocator.free(raw_value);

    return try self.parseLeaky(T, raw_value, opts);
}

/// See document from `Reader.read()` for supported types in a struct fields
pub fn readStruct(self: Self, comptime T: type, comptime opts: Options) !T {
    if (@typeInfo(T) != .@"struct") {
        @compileError(std.fmt.comptimePrint("Expected a `struct` found {s}\n", @typeName(@typeInfo(T))));
    }
    const allocator = self.allocator;

    // Allocate to init a struct without any field default value.
    const @"struct" = try allocator.create(T);
    defer allocator.destroy(@"struct");

    inline for (@typeInfo(T).@"struct".fields) |field| {
        var buffer: [field.name.len]u8 = undefined;
        _ = std.ascii.upperString(buffer[0..], field.name);
        const value = try self.readKey(field.type, buffer[0..], opts) orelse {
            std.log.scoped(.zenv).err("Not found environment {s} in struct {s}\n", .{ buffer, @typeName(T) });
            return error.MissingField;
        };

        @field(@"struct", field.name) = value;
    }
    return @"struct".*;
}

/// - Parse a raw value ([]const u8) when reading env by `Reader.read()`.
/// # Supported types:
/// * builtin.Int
/// * []const u8 or []u8
pub fn parseLeaky(self: Self, comptime T: type, value: []const u8, opts: Options) !T {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => {
            var trimmed = value[0..];
            if (opts.trim) {
                trimmed = std.mem.trim(u8, value[0..], " ");
            }
            return try std.fmt.parseInt(T, trimmed, 10);
        },
        .pointer => |pointerInfo| {
            if (pointerInfo.child == u8) {
                var trimmed = value[0..];
                if (opts.trim) {
                    trimmed = std.mem.trim(u8, value[0..], " ");
                }
                const new_buffer = try self.allocator.alloc(u8, trimmed.len);
                @memcpy(new_buffer[0..], trimmed[0..]);
                return new_buffer[0..];
            } else {
                std.log.scoped(.zenv).err("Not supported type: {s}\n", .{@typeName(T)});
                return error.NotSupportedType;
            }
        },
        else => {
            std.log.scoped(.zenv).err("Not supported type: {s}\n", .{@typeName(T)});
            return error.NotSupportedType;
        },
    };
}
