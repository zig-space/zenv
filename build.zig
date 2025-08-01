const std = @import("std");
const builtin = @import("builtin");

const minimum_zig_version = std.SemanticVersion.parse("0.14.1") catch @panic("Error occurs when parse version");

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

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zenv = b.addModule("zenv", .{
        .root_source_file = b.path("src/lib.zig"),
    });

    const zlint_step = b.step("zlint", "Run zlint if exists");
    if (b.findProgram(&.{"zlint"}, &.{}) catch null) |zlint_path| {
        const zlint_cmd = b.addSystemCommand(&.{zlint_path});
        zlint_step.dependOn(&zlint_cmd.step);
        b.getInstallStep().dependOn(zlint_step);
    }

    {
        // Display output when run by cmd
        const main_tests_cmd = b.addSystemCommand(&.{ "sh", "-c", "zig test src/lib.zig 2>&1 | cat" });
        // SET ENV FOR TEST IT WILL BE REMOVED AFTER TESTS
        main_tests_cmd.setEnvironmentVariable("TEST_SLICE", "test");
        main_tests_cmd.setEnvironmentVariable("TEST_NUMBER", "0");
        main_tests_cmd.setEnvironmentVariable("PREFIX_SLICE", "prefix");
        main_tests_cmd.setEnvironmentVariable("VALUE1", "value1");
        main_tests_cmd.setEnvironmentVariable("VALUE2", "2");
        main_tests_cmd.setEnvironmentVariable("VALUE3", "3");
        main_tests_cmd.setEnvironmentVariable("DB_PORT", "5432");
        main_tests_cmd.setEnvironmentVariable("DB_USERNAME", "root_username");
        main_tests_cmd.setEnvironmentVariable("DB_PASSWORD", "root_password");
        main_tests_cmd.setEnvironmentVariable("NOT_SUPPORTED_TYPE", "false");
        const run_test_step = b.step("test", "Run the test and display output in console");
        run_test_step.dependOn(&main_tests_cmd.step);
    }

    // Terminal example
    {
        const term_exe = b.addExecutable(.{
            .name = "term_example",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/term.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        b.installArtifact(term_exe);
        const run_term = b.addRunArtifact(term_exe);
        const run_term_step = b.step("run-term", "Run the terminal example");

        run_term.setEnvironmentVariable("TEST_SLICE", "test");
        run_term.setEnvironmentVariable("VALUE1", "value1");
        run_term.setEnvironmentVariable("VALUE2", "2");
        run_term.setEnvironmentVariable("VALUE3", "3");

        term_exe.root_module.addImport("zenv", zenv);
        run_term_step.dependOn(&run_term.step);
    }
    // Dotenv example
    {
        const file_exe = b.addExecutable(.{
            .name = "file_example",
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/dotenv.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        b.installArtifact(file_exe);
        const run_file = b.addRunArtifact(file_exe);
        const run_file_step = b.step("run-dotenv", "Run the terminal example");

        run_file.setEnvironmentVariable("TEST_SLICE", "test");
        run_file.setEnvironmentVariable("VALUE1", "value1");
        run_file.setEnvironmentVariable("VALUE2", "2");
        run_file.setEnvironmentVariable("VALUE3", "3");

        file_exe.root_module.addImport("zenv", zenv);
        run_file_step.dependOn(&run_file.step);
    }
}
