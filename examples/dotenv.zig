const std = @import("std");
const zenv = @import("zenv");

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}).init;
    defer {
        const check = da.deinit();
        if (check == .leak) {
            std.log.debug("Leak memory is detected in the file example", .{});
        }
    }

    const alloc = da.allocator();
    // NOTE: Using file path in the current working directory
    var dotenv = try zenv.Dotenv.init(alloc, "examples/.env", 1024);
    defer dotenv.deinit();

    const reader = dotenv.reader();
    // NOTE: Read a key with prefix
    const slice = (try reader.readKey([]const u8, "SLICE", .{ .prefix = "PREFIX_" })) orelse "null";
    std.log.debug("Slice: {s}", .{slice});
    const whitespace = (try reader.readKey([]const u8, "WHITESPACE", .{ .prefix = "TEST_", .trim = false })) orelse "null";
    std.log.debug("WHITESPACE: {s} - len: {d}", .{ whitespace, whitespace.len });

    // NOTE: Read a struct
    const Test = struct {
        value1: []const u8,
        value2: u8,
        value3: u16,
    };

    const struct_value = try reader.readStruct(Test, .{ .prefix = "TEST_" });
    std.log.debug("Value 1: {s}", .{struct_value.value1});
    std.log.debug("Value 2: {d}", .{struct_value.value2});
    std.log.debug("Value 3: {d}", .{struct_value.value3});
}
