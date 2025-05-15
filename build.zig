const std = @import("std");
const builtin = @import("builtin");

const minimum_zig_version = std.SemanticVersion.parse("0.15.0-dev.471+369177f0b") catch unreachable;

pub fn build(b: *std.Build) void {
    comptime if (builtin.zig_version.order(minimum_zig_version) == .lt) {
        @compileError(std.fmt.comptimePrint(
            \\Your Zig version does not meet the minimum build requirement:
            \\Required     Zig version: {[minimum_version]}
            \\Your current Zig version: {[current_version]}
        , .{
            .minimum_version = minimum_zig_version,
            .current_version = builtin.zig_version,
        }));
    };
    comptime if (builtin.os.tag != .linux) {
        @compileError(@tagName(builtin.os.tag) ++ "is not supported!");
    };
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

    // Display output when run by cmd
    const main_tests_cmd = b.addSystemCommand(&.{ "sh", "-c", "zig test src/lib.zig 2>&1 | cat" });
    const run_test_step = b.step("test", "Run the test and display output in console");
    run_test_step.dependOn(&main_tests_cmd.step);
}
