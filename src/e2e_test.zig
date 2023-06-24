const std = @import("std");
const VirtualMachine = @import("virtual_machine.zig");

fn e2e_test(input: []const u8, expected_output: []const u8) !void {
    var source = try std.fs.cwd().createFile("output.txt", .{ .read = true, .lock = .Exclusive });
    defer source.close();
    var writer = source.writer();
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();
    writer.print("test", {});
    var vm = VirtualMachine.init(&writer, allocator);
    defer vm.deinit();
    try vm.interpret(input);
    var buf: [1024]u8 = undefined;
    try source.seekTo(0);
    const read = try source.read(&buf);
    // Ignoring the last byte because it is a new line
    try std.testing.expectEqualStrings(expected_output[0 .. read - 1], buf[0 .. read - 1]);
    try std.fs.cwd().deleteFile("output.txt");
}

test "Redirect IO" {
    try e2e_test("print \"Hello World\"; ", "Hello World");
}
