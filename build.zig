const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("zenv", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    const lib = b.addStaticLibrary(.{
        .name = "zenv",
        .root_source_file = b.path("src/lib.zig"),
        .optimize = optimize,
        .target = target,
    });
    b.installArtifact(lib);
}
