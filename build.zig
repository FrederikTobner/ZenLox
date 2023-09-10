const std = @import("std");

pub fn build(b: *std.build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // Debug options making it easier to debug the VM
    const debug_options = b.addOptions();

    // Option to enable tracing of the VM
    const trace_execution = b.option(bool, "traceExecution", "Trace execution of the VM");
    debug_options.addOption(bool, "traceExecution", trace_execution orelse false);

    // Option to print the bytecode of the compiled code
    const print_bytecode = b.option(bool, "printBytecode", "Printing the bytcode of the compiled code");
    debug_options.addOption(bool, "printBytecode", print_bytecode orelse false);

    const exe = b.addExecutable(.{
        .name = "ZenLox",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Adds the debug options to the executable of the interpreter
    exe.addOptions("debug_options", debug_options);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // The executable for running the tests
    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "test.zig" },
        .target = target,
        .optimize = optimize,
    });
    // Adding the debug options to the test executable
    exe_tests.addOptions("debug_options", debug_options);

    const run_tests = b.addRunArtifact(exe_tests);

    // Adding a custom step to run the tests
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}