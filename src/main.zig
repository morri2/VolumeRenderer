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
