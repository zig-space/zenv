const std = @import("std");

pub fn hello() void {
    std.log.debug("Helo World", .{});
}
