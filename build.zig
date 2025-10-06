const std = @import("std");

pub fn build(b: *std.Build) void {
    const t = b.standardTargetOptions(.{});
    const o = b.standardOptimizeOption(.{});

    _ = b.addModule("zdi", .{
        .root_source_file = b.path("src/main.zig"),
        .target = t,
        .optimize = o,
    });

    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = t,
            .optimize = o,
        }),
    });
    const run_test_step = b.step("test", "Run unit tests");
    const run_test = b.addRunArtifact(test_exe);
    run_test_step.dependOn(&run_test.step);
}
