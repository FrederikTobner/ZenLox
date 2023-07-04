comptime {
    _ = @import("src/lexer.zig");
    _ = @import("src/token.zig");
    _ = @import("src/fnv1a.zig");
    _ = @import("src/table.zig");
    _ = @import("src/virtual_machine.zig");
    _ = @import("src/test/e2e_tests.zig");
}
