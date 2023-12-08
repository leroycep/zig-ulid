const Builder = @import("std").build.Builder;

const EXAMPLES_DIR = "examples";
const EXAMPLES = [_][]const u8{
    "generate-ulid",
};

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ulid = b.addModule("ulid", .{
        .source_file = .{ .path = "ulid.zig" },
    });

    const ulid_lib = b.addStaticLibrary(.{
        .name = "ulid",
        .root_source_file = .{ .path = "ulid.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(ulid_lib);

    const main_tests_exe = b.addTest(.{
        .root_source_file = .{ .path = "ulid.zig" },
        .target = target,
        .optimize = optimize,
    });

    const main_tests = b.addRunArtifact(main_tests_exe);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const run_tests_and_build_examples = b.step("run-tests-and-build-examples", "Run tests and build examples; run to make sure everything works");
    run_tests_and_build_examples.dependOn(&main_tests.step);

    inline for (EXAMPLES) |example| {
        const exe = b.addExecutable(.{
            .name = example,
            .root_source_file = .{ .path = EXAMPLES_DIR ++ "/" ++ example ++ ".zig" },
            .target = target,
            .optimize = optimize,
        });
        exe.addModule("ulid", ulid);

        run_tests_and_build_examples.dependOn(&exe.step);

        const run_exe = b.addRunArtifact(exe);

        const example_step = b.step("example-" ++ example, "Run the " ++ example ++ " example");
        example_step.dependOn(&run_exe.step);
    }
}
