const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});

    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("mpunksminer", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);

    exe.linkLibC();
    exe.addIncludeDir("./src/opencl-headers");
    if (target.os_tag == null) {
        exe.linkFramework("OpenCL");
    } else {
        var tag = target.os_tag.?;
        if (tag == std.Target.Os.Tag.macos) {
            exe.linkFramework("OpenCL");
        } else if (tag == std.Target.Os.Tag.linux or tag == std.Target.Os.Tag.windows) {
            exe.linkSystemLibraryName("OpenCL");
        }
    }

    exe.install();

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const gpu_cmd = exe.run();
    gpu_cmd.addArg("--gpu");
    gpu_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        gpu_cmd.addArgs(args);
    }

    const gpu_step = b.step("gpu", "Run the app on GPU mode");
    gpu_step.dependOn(&gpu_cmd.step);

    const test_cmd = exe.run();
    test_cmd.addArg("--test");
    test_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        test_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run the app on test mode");
    test_step.dependOn(&test_cmd.step);
}
