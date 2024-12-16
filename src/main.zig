const std = @import("std");
const KDtree = @import("KDtree.zig");
const Vec3 = @import("vec3.zig").Vec3(f32);
pub fn main() !void {
    const tree = KDtree.newTestTree();
    tree.printTree();

    std.debug.print("\n\n", .{});

    const a = Vec3.zero().add();
    a.print();
    const b = Vec3.new(0.2, 0.5, 0.99);
    a.mul(b).print();
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
