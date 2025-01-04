const KDtree = @import("KDtree.zig");
const std = @import("std");
const geo = @import("geo.zig");
const zigimg = @import("zigimg");

const SPACESIZE = @import("typedef.zig").SPACESIZE;
const ISOVAL = @import("typedef.zig").ISOVAL;

pub fn frame(src: geo.VecF, forw: geo.VecF, up: geo.VecF, x: u32, y: u32, pixel_size: f32, kdt: KDtree, isoval: ISOVAL) !void {
    const right = forw.cross(up);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var img = try zigimg.Image.create(allocator, x, y, .grayscale8);
    defer img.deinit();

    for (0..y) |yi| {
        const yf = (@as(f32, @floatFromInt(y)) - @as(f32, @floatFromInt(yi / 2))) * pixel_size;
        for (0..x) |xi| {
            const xf = (@as(f32, @floatFromInt(x)) - @as(f32, @floatFromInt(xi / 2))) * pixel_size;
            const dir = forw.add(up.scale(yf).add(right.scale(xf))).norm();
            const res = traceRay(.{ .dir = dir, .origin = src }, &kdt, isoval);

            if (res > 0.0) {
                img.pixels.grayscale8[yi * x + x] = zigimg.color.Grayscale8{ .value = 255 };
            } else {
                img.pixels.grayscale8[yi * x + x] = zigimg.color.Grayscale8{ .value = 0 };
            }
        }
    }
    try img.writeToFilePath("out.png", .{ .png = .{} });
}

pub fn traceRay(ray: geo.Ray, kdt: *const KDtree, isoval: ISOVAL) f32 {
    const dir_off = ray.dir.gtz().cell().?;

    var t: f32 = 0.0;

    var node_idx: u32 = KDtree.ROOT;

    t = 999999999.0;
    const root_planes = kdt.nodes[node_idx].space.planes();
    t = @min(t, root_planes[0].rayIntersect(ray));
    t = @min(t, root_planes[1].rayIntersect(ray));
    t = @min(t, root_planes[2].rayIntersect(ray));
    t = @min(t, root_planes[3].rayIntersect(ray));
    t = @min(t, root_planes[4].rayIntersect(ray));
    t = @min(t, root_planes[5].rayIntersect(ray));
    if (t < 0) t = 0.0;

    while (kdt.nodes[KDtree.ROOT].space.containsFloat(ray.point(t))) {
        const cell = ray.point(t).cell().?;
        // if ISO in range: ZOOM
        if (kdt.nodes[node_idx].dens_range.contains(isoval)) {
            if (kdt.zoom(node_idx, cell)) |cell_node_idx| {
                node_idx = cell_node_idx;
                continue;
            } else {
                return t;
            }
        }

        const planes = kdt.nodes[node_idx].space.planes();

        std.debug.print("t= {d} ", .{t});

        t = 999999.0;

        t = @min(t, planes[1 - dir_off.x].rayIntersect(ray));
        t = @min(t, planes[3 - dir_off.y].rayIntersect(ray));
        t = @min(t, planes[5 - dir_off.z].rayIntersect(ray));
        t += 0.0001; // mini offset

        std.debug.print(" -> t= {d} ({d} {d} {d})\n", .{ t, ray.point(t).x, ray.point(t).y, ray.point(t).z });
        // else Move ON

        std.debug.assert(!kdt.nodes[node_idx].space.containsFloat(ray.point(t)));
        while (!kdt.nodes[node_idx].space.contains(cell)) {
            if (node_idx == KDtree.ROOT) break;
            node_idx = KDtree.parent(node_idx);
        }
    }
    return -1.0;
}
