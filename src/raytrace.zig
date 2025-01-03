const KDtree = @import("KDtree.zig");
const Space = @import("Space.zig");
const Point = Space.Point;
const Coord = Space.Coord;
const std = @import("std");
const zigimg = @import("zigimg");

pub const Ray = struct {
    origin: Point,
    dir: Point,

    pub fn point(self: @This(), t: f32) Point {
        return self.origin.add(self.dir.scale(t));
    }
};

pub fn frame(src: Point, forw: Point, up: Point, x: u32, y: u32, pixel_size: f32, kdt: KDtree, isoval: u32) void {
    const right = forw.cross(up);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var img = try zigimg.Image.create(allocator, 256, 256, .grayscale8);
    defer img.deinit();

    for (0..y) |yi| {
        const yf = @as(f32, @floatFromInt(yi - y / 2)) * pixel_size;
        for (0..x) |xi| {
            const xf = @as(f32, @floatFromInt(xi - x / 2)) * pixel_size;
            const dir = forw.add(up.scale(yf).add(right.scale(xf))).norm();
            const res = traceRay(.{ .dir = dir, .origin = src }, kdt, isoval);

            if (res > 0.0) {
                img.pixels.grayscale8[yi * x + x] = zigimg.color.Grayscale8(255);
            } else {
                img.pixels.grayscale8[yi * x + x] = zigimg.color.Grayscale8(0);
            }
        }
    }
    try img.writeToFilePath("out.png", .{ .png = .{} });
}

pub fn traceRay(ray: Ray, kdt: KDtree, isoval: u32) f32 {
    const dir_off = ray.dir.gtz().cell();

    var t = 0.0;
    var cell = ray.point(t).cell();
    var node_idx = KDtree.ROOT;

    while (kdt.nodes[KDtree.ROOT].space.contains(cell)) {

        // if ISO in range: ZOOM
        if (kdt.nodes[node_idx].dens_range.contains(isoval)) {
            const maybe_node_idx = kdt.zoom(node_idx, kdt.nodes[node_idx]);
            if (!maybe_node_idx) {
                // AT LEAF
                // THING DONE WE RETURN / interp
                return t;
            } else {
                // ZOOM IN
                node_idx = maybe_node_idx.?;
                continue;
            }
        }

        const planes = kdt.nodes[node_idx].space.planes();

        t = 999999999.0;

        t = @min(t, planes[0 + dir_off.x].rayIntersect(ray));
        t = @min(t, planes[2 + dir_off.y].rayIntersect(ray));
        t = @min(t, planes[4 + dir_off.z].rayIntersect(ray));
        // t += 0.00001; // mini offset

        // else Move ON

        cell = ray.point(t).cell();
        std.debug.assert(!kdt.nodes[node_idx].space.contains(cell));
        while (!kdt.nodes[node_idx].space.contains(cell)) {
            if (node_idx == KDtree.ROOT) break;
            node_idx = KDtree.parent(node_idx);
        }
    }
    return -1.0;
}
