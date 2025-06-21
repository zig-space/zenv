//! Create your custom reader with Zenv.
const std = @import("std");
const zenv = @import("zenv");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

pub const CustomReader = struct {
    extra_field: []const u8,
    // Allocator from arena
    allocator: std.mem.Allocator,
    // Internal arena
    _arena: *std.heap.ArenaAllocator,

    pub fn init(alloc: Allocator) !CustomReader {
        // NOTE: Suggest using ArenaAllocator to make all
        //       env have the longest lifetime with the application
        //       and free once at the end of application.
        const arena = try alloc.create(ArenaAllocator);
        arena.* = ArenaAllocator.init(alloc);
        return .{
            .extra_field = "hehe",
            .allocator = arena.allocator(),
            ._arena = arena,
        };
    }

    pub fn deinit(self: *CustomReader) void {
        const alloc = self._arena.child_allocator;
        self._arena.deinit();
        alloc.destroy(self._arena);
    }

    pub fn reader(self: *const CustomReader) zenv.Reader {
        return .{
            .allocator = self.allocator,
            .ptr = @constCast(self),
            .vtable = .{
                .readFn = read, // Put your rules when reading a key here
            },
        };
    }

    pub fn read(ctx: *const anyopaque, key: []const u8) !?[]const u8 {
        // Get your struct via ctx
        const self: *const CustomReader = @ptrCast(@alignCast(ctx));
        _ = self;
        // handle the rest of your function to read env here
        // NOTE: In this example, this handler
        //       always return a raw value same
        //       with the input key.
        return key;
    }
};
