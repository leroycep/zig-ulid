const Builder = @import("std").build.Builder;

const EXAMPLES_DIR = "examples";
const EXAMPLES = [_][]const u8{
    "generate-ulid",
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("ulid", "ulid.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("ulid.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const target = b.standardTargetOptions(.{});
    inline for (EXAMPLES) |example| {
        var exe = b.addExecutable(example, EXAMPLES_DIR ++ "/" ++ example ++ ".zig");
        exe.addPackage(.{ .name = "ulid", .path = .{ .path = "ulid.zig" } });
        exe.setBuildMode(mode);
        exe.setTarget(target);

        const example_step = b.step("example-" ++ example, "Run the " ++ example ++ " example");
        example_step.dependOn(&exe.run().step);
    }
}
