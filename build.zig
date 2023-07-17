const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    // The default is Debug.
    const mode = b.standardReleaseOptions();

    // Debug options making it easier to debug the VM
    const debug_options = b.addOptions();
    // Option to enable tracing of the VM
    const trace_execution = b.option(bool, "traceExecution", "Trace execution of the VM");
    debug_options.addOption(bool, "traceExecution", trace_execution orelse false);
    // Option to print the bytecode of the compiled code
    const print_bytecode = b.option(bool, "printBytecode", "Printing the bytcode of the compiled code");
    debug_options.addOption(bool, "printBytecode", print_bytecode orelse false);

    const exe = b.addExecutable("ZenLox", "src/main.zig");
    // Adding debug options to the executable
    exe.addOptions("debug_options", debug_options);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    // Adding a custom step to run the executable
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    // Custom step to run ZenLox
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // The executable for running the tests
    const exe_tests = b.addTest("test.zig");
    exe_tests.addOptions("debug_options", debug_options);
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);
    // Adding a custom step to run the tests
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
