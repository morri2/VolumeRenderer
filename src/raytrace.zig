const std = @import("std");
//const KDtree = @import("KDtree.zig");
const Data = @import("Data.zig");
const zigimg = @import("zigimg");
//const raytrace = @import("raytrace.zig");
const geo = @import("geo.zig");
const SlimKDT = @import("SlimKDT.zig");
const ISOVAL = @import("typedef.zig").ISOVAL;
const zbench = @import("zbench");

pub fn renderImage(
    src: geo.VecF,
    forw: geo.VecF,
    up: geo.VecF,
    img: *zigimg.Image,
    viewport_width: f32,
    kdt: *const SlimKDT,
    isoval: ISOVAL,
    comptime dbp: bool,
    comptime inner_dbp: bool,
) !struct { nodes_checked: u64 } {
    const width = img.width;
    const height = img.height;
    const pixel_size = viewport_width / @as(f32, @floatFromInt(width));

    // DATA COLLECTION
    var oob_count: f32 = 0;
    var miss_count: f32 = 0;
    var hit_count: f32 = 0;
    var avg_hit_t: f32 = 0;
    var min_hit_t: f32 = std.math.inf(f32);
    var max_hit_t: f32 = 0;
    var node_checks: u64 = 0;

    var escape_help_events: f32 = 0;

    //setup
    const right = forw.cross(up);

    for (0..height) |yi| {
        const yf = (@as(f32, @floatFromInt(yi)) - @as(f32, @floatFromInt(height / 2))) * pixel_size;
        for (0..width) |xi| {
            const xf = (@as(f32, @floatFromInt(xi)) - @as(f32, @floatFromInt(width / 2))) * pixel_size;

            const dir = forw.add(up.scale(yf).add(right.scale(xf))).norm();

            const res = SlimKDT.traceRay(
                .{ .dir = dir, .origin = src },
                kdt,
                isoval,
                inner_dbp,
            );
            if (res.oob) {
                img.pixels.rgb24[yi * width + xi] = .{ .r = 20, .g = 0, .b = 90 };
                oob_count += 1;
            } else if (res.hit) {
                img.pixels.rgb24[yi * width + xi] = .{
                    .r = 255 - @as(u8, @intFromFloat(@min(200, res.t - 300))),
                    .b = 255 - @as(u8, @intFromFloat(@min(200, res.t - 300))),
                    .g = 255 - @as(u8, @intFromFloat(@min(200, res.t - 300))),
                };
                hit_count += 1;
                avg_hit_t += res.t;
                min_hit_t = @min(res.t, min_hit_t);
                max_hit_t = @max(res.t, max_hit_t);
            } else {
                img.pixels.rgb24[yi * width + xi] = .{ .r = 0, .g = 0, .b = 0 };
                miss_count += 1;
            }
            node_checks += res.checked_nodes;
            escape_help_events += res.escape_help_count;
        }
        if (comptime dbp) {
            if ((yi * 10) % height == 0) {
                std.debug.print("\n{}% done\n", .{(yi * 100) / height});
            }
        }
    }
    if (hit_count > 0) avg_hit_t /= hit_count;
    if (comptime dbp) {
        std.debug.print(
            \\
            \\Done!
            \\
            \\ {d:.1}% hits
            \\ {d:.1}% oobs
            \\ {d:.1}% miss
            \\
            \\ {d:.1} avg t (hits). range: {d:.1}-{d:.1}
            \\ {d:.1} escape help events
            \\ {} nodes checked
            \\
            \\
        , .{
            100 * hit_count / @as(f32, @floatFromInt(width * height)),
            100 * oob_count / @as(f32, @floatFromInt(width * height)),
            100 * miss_count / @as(f32, @floatFromInt(width * height)),
            avg_hit_t,
            min_hit_t,
            max_hit_t,
            escape_help_events,
            node_checks,
        });
    }
    return .{ .nodes_checked = node_checks };
}

pub fn trilerp(
    x: f32,
    y: f32,
    z: f32,
    x0: f32,
    x1: f32,
    y0: f32,
    y1: f32,
    z0: f32,
    z1: f32,
    values: [8]f32, // vertex values v000, v100, v010, v110, v001, v101, v011, v111
) f32 {
    const xd = (x - x0) / (x1 - x0);
    const yd = (y - y0) / (y1 - y0);
    const zd = (z - z0) / (z1 - z0);

    const v000 = values[0];
    const v100 = values[1];
    const v010 = values[2];
    const v110 = values[3];
    const v001 = values[4];
    const v101 = values[5];
    const v011 = values[6];
    const v111 = values[7];

    const c00 = v000 * (1 - xd) + v100 * xd;
    const c10 = v010 * (1 - xd) + v110 * xd;
    const c01 = v001 * (1 - xd) + v101 * xd;
    const c11 = v011 * (1 - xd) + v111 * xd;

    const c0 = c00 * (1 - yd) + c10 * yd;
    const c1 = c01 * (1 - yd) + c11 * yd;

    return c0 * (1 - zd) + c1 * zd;
}

const step_size = 0.1;

pub fn trilerpTrace(ray: geo.Ray, cell: geo.Cell, st: SlimKDT.SpaceTracker, t_start: f32, isoval: ISOVAL) bool {
    _ = ray; // autofix
    _ = t_start; // autofix
    _ = isoval; // autofix

    const vals = st.kdt.data.getCornerDens(cell);
    _ = vals; // autofix
    //var last_val: u8 = 0;

}
