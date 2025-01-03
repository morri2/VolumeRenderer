const std = @import("std");
const KDtree = @import("KDtree.zig");
const Vec3 = @import("vec3.zig").Vec3(f32);
const Data = @import("Data.zig");
const zigimg = @import("zigimg");
const raytrace = @import("raytrace.zig");
const Space = @import("Space.zig");
pub fn main() !void {
    const tree = KDtree.newTestTree();
    tree.printTree();

    std.debug.print("\n\n", .{});

    const a = try Data.loadUCD();

    try renderSlice(a, 18);
    // raytrace.frame(
    //     Space.Point.new(0, 0, 0),
    //     Space.Point.new(0, 0, 1.0),
    //     Space.Point.new(1.0, 0, 0),
    //     100,
    //     100,

    // );
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

pub fn renderSlice(data: Data, x: u32) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var img = try zigimg.Image.create(allocator, 256, 256, .grayscale8);
    defer img.deinit();

    for (0..256) |r| {
        for (0..256) |c| {
            const v = data.get(x, @intCast(r), @intCast(c));
            img.pixels.grayscale8[r * 256 + c] = zigimg.color.Grayscale8{ .value = v };
        }
    }
    try img.writeToFilePath("out.png", .{ .png = .{} });
}
