const std = @import("std");
const KDtree = @import("KDtree.zig");
const Data = @import("Data.zig");
const zigimg = @import("zigimg");
const raytrace = @import("raytrace.zig");
const geo = @import("geo.zig");
pub fn main() !void {
    //const tree = KDtree.newTestTree();
    //_ = tree; // autofix
    //tree.printTree();

    std.debug.print("\n\n", .{});

    var data = try Data.loadUCDcapped(32);
    data = data; // autofix

    try renderSlice(data, 18);

    const kdt = KDtree.binaryPartionFromData(&data);
    _ = kdt; // autofix

    // try raytrace.frame(
    //     geo.Vec3(f32).new(0, 0, 0),
    //     geo.Vec3(f32).new(0, 0, 1.0),
    //     geo.Vec3(f32).new(1.0, 0, 0),
    //     100,
    //     100,
    //     0.1,
    //     kdt,
    //     98,
    // );
}

pub fn renderSlice(data: Data, x: u32) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var img = try zigimg.Image.create(allocator, data.resulution[1], data.resulution[2], .grayscale8);
    defer img.deinit();

    for (0..data.resulution[1]) |r| {
        for (0..data.resulution[2]) |c| {
            const v = data.get(x, @intCast(r), @intCast(c));
            img.pixels.grayscale8[r * data.resulution[1] + c] = zigimg.color.Grayscale8{ .value = v };
        }
    }
    try img.writeToFilePath("out.png", .{ .png = .{} });
}
