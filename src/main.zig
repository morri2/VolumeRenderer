const std = @import("std");
const KDtree = @import("KDtree.zig");
const Data = @import("Data.zig");
const zigimg = @import("zigimg");
const raytrace = @import("raytrace.zig");
const geo = @import("geo.zig");
const SlimKDT = @import("SlimKDT.zig");
pub fn main() !void {
    //const tree = KDtree.newTestTree();
    //_ = tree; // autofix
    //tree.printTree();
    std.debug.print("", .{});

    std.debug.print("hello\n\n", .{});

    var data = try Data.loadUCDcapped(32);
    data = data; // autofix

    const kdt = SlimKDT.newEvenPartition(&data);

    _ = SlimKDT.traceRay(.{ .dir = geo.Vec3(f32).new(0.5, 0.5, 0.5).norm(), .origin = geo.Vec3(f32).new(0, 0, 0) }, &kdt, 99);
    //try renderSlice(data, 18);

    //const p1: geo.Plane(u32) = .{ .normal_axis = .X, .offset = 0 };
    //
    //const r1: geo.Ray = .{
    //    .dir = geo.Vec3(f32).new(1.0, 1.0, 0.0).norm(),
    //    .origin = geo.Vec3(f32).new(-3, 0, 6),
    //};
    //
    //const res = p1.rayIntersect(r1);
    //
    //std.debug.print("res: {d}", .{res});
    //r1.point(res).print();

    //const kdt = KDtree.binaryPartionFromData(&data);

    //try raytrace.frame(
    //    geo.Vec3(f32).new(0, 0, -10.2),
    //    geo.Vec3(f32).new(0, 0, 1.0),
    //    geo.Vec3(f32).new(1.0, 0, 0),
    //    20,
    //    20,
    //    0.001,
    //    kdt,
    //    98,
    //);
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
