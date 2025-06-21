//! The reader following dotenv (.env) file format
const std = @import("std");
const Reader = @import("Reader.zig");
const Self = @This();

allocator: std.mem.Allocator,
env_map: std.StringHashMap([]const u8),
_arena: *std.heap.ArenaAllocator,

pub fn init(alloc: std.mem.Allocator, file_path: []const u8, file_max_size: usize) !Self {
    const arena = try alloc.create(std.heap.ArenaAllocator);
    arena.* = std.heap.ArenaAllocator.init(alloc);

    const file = std.fs.cwd().openFile(file_path, .{ .mode = .read_only }) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.scoped(.zenv).err("File `{s}` not found!", .{file_path});
            return err;
        },
        else => return err,
    };
    const map = try readAllToMap(arena.allocator(), file, file_max_size);
    return .{
        .env_map = map,
        .allocator = arena.allocator(),
        ._arena = arena,
    };
}
pub fn deinit(self: *Self) void {
    const alloc = self._arena.child_allocator;
    self.env_map.deinit();
    self._arena.deinit();
    alloc.destroy(self._arena);
}

pub fn reader(self: *const Self) Reader {
    return .{
        .allocator = self.allocator,
        .ptr = @constCast(self),
        .vtable = .{ .readFn = read },
    };
}

pub fn read(ctx: *const anyopaque, key: []const u8) !?[]const u8 {
    const self: *const Self = @ptrCast(@alignCast(ctx));
    return self.env_map.get(key);
}

fn readAllToMap(
    alloc: std.mem.Allocator,
    file: std.fs.File,
    max_size: usize,
) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(alloc);
    errdefer map.deinit();
    const content: []u8 = try file.reader().readAllAlloc(alloc, max_size);
    defer alloc.free(content);
    var splits: std.mem.TokenIterator(u8, .any) = undefined;
    if (@import("builtin").os.tag == .windows) {
        splits = std.mem.tokenizeAny(u8, content, "\r\n");
    } else {
        splits = std.mem.tokenizeAny(u8, content, "\n");
    }

    while (splits.next()) |line| {
        if (line.len == 0) continue;
        if (std.mem.startsWith(u8, line, "#")) continue;
        const eql_seperator = std.mem.indexOfScalar(u8, line, '=') orelse {
            std.log.err("Failed when parse a non-empty line, we cannot find your `=`!", .{});
            return error.InvalidLine;
        };
        const trimmed_name = std.mem.trim(u8, line[0..eql_seperator], " ");
        const raw_value = line[eql_seperator + 1 ..];
        try map.put(
            try alloc.dupe(u8, trimmed_name),
            try alloc.dupe(u8, raw_value),
        );
    }
    return map;
}
