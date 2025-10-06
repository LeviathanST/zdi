const std = @import("std");

pub fn build(b: *std.Build) void {
    const t = b.standardTargetOptions(.{});
    const o = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zdi",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = t,
            .optimize = o,
        }),
    });

    b.installArtifact(exe);
    const run_exe_step = b.step("run", "Run the application");
    const run_exe = b.addRunArtifact(exe);
    exe.root_module.addImport("zdi", b.dependency("zdi", .{}).module("zdi"));
    run_exe_step.dependOn(&run_exe.step);
}
