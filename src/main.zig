const std = @import("std");
//const KDtree = @import("KDtree.zig");
const Data = @import("Data.zig");
const zigimg = @import("zigimg");
//const raytrace = @import("raytrace.zig");
const geo = @import("geo.zig");
const SlimKDT = @import("SlimKDT.zig");
const ISOVAL = @import("typedef.zig").ISOVAL;
pub fn main() !void {
    //const tree = KDtree.newTestTree();
    //_ = tree; // autofix
    //tree.printTree();
    std.debug.print("", .{});

    std.debug.print("hello\n\n", .{});

    var data = try Data.loadUCDcapped("Skull.vol", 255);
    data = data; // autofix

    // const memory = try allocator.alloc(KDtree, 1);
    // defer allocator.free(memory);

    //const kdt: SlimKDT = .{ .nodes = undefined, .root_dim = .{ 0, 0, 0 }, .root_space = geo.Volume(u8).new(.{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }) };

    const kdt = SlimKDT.newEvenPartition(&data);
    //_ = kdt; // autofix

    const data_center = geo.Vec3(f32).new(
        @floatFromInt(data.resulution[0] / 2),
        @floatFromInt(data.resulution[1] / 2),
        @floatFromInt(data.resulution[2] / 2),
    );
    const camera_pos = geo.Vec3(f32).new(-8, 0, -8);
    const camera_dir = data_center.sub(camera_pos).norm();

    var c = camera_dir;
    c = c.cross(geo.Vec3(f32).new(0.0, 1.0, 0.0));
    c = c.cross(camera_dir);

    const camera_up = c;

    std.debug.print(
        \\
        \\
        \\ Raytracing
        \\ camera: ({d:.2} {d:.2} {d:.2})
        \\ facing: ({d:.2} {d:.2} {d:.2})
        \\ up:     ({d:.2} {d:.2} {d:.2})
        \\
        \\
        \\
    , .{ camera_pos.x, camera_pos.y, camera_pos.z, camera_dir.x, camera_dir.y, camera_dir.z, camera_up.x, camera_up.y, camera_up.z });

    std.debug.print("RT start...\n", .{});
    const start_time = std.time.milliTimestamp();

    try slimRT(
        camera_pos,
        data_center.sub(camera_pos).norm(),
        camera_up,
        1000,
        1000,
        2.0,
        kdt,
        50,
        true,
        false,
    );

    const end_time = std.time.milliTimestamp();

    std.debug.print("RT end... {}ms\n", .{end_time - start_time});
}

pub fn slimRT(
    src: geo.VecF,
    forw: geo.VecF,
    up: geo.VecF,
    width: u32,
    height: u32,
    viewport_width: f32,
    kdt: SlimKDT,
    isoval: ISOVAL,
    comptime dbp: bool,
    comptime inner_dbp: bool,
) !void {
    const pixel_size = viewport_width / @as(f32, @floatFromInt(width));

    // DATA COLLECTION
    var oob_count: f32 = 0;
    var miss_count: f32 = 0;
    var hit_count: f32 = 0;
    var avg_hit_t: f32 = 0;

    //setup
    const right = forw.cross(up);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var img = try zigimg.Image.create(allocator, width, height, .rgb24);
    defer img.deinit();

    for (0..height) |yi| {
        const yf = (@as(f32, @floatFromInt(yi)) - @as(f32, @floatFromInt(height / 2))) * pixel_size;
        for (0..width) |xi| {
            const xf = (@as(f32, @floatFromInt(xi)) - @as(f32, @floatFromInt(width / 2))) * pixel_size;

            const dir = forw.add(up.scale(yf).add(right.scale(xf))).norm();

            const res = SlimKDT.traceRay(
                .{ .dir = dir, .origin = src },
                &kdt,
                isoval,
                inner_dbp,
            );
            if (res.oob) {
                img.pixels.rgb24[yi * width + xi] = .{ .r = 0, .g = 255, .b = 0 };
                oob_count += 1;
            } else if (res.hit) {
                img.pixels.rgb24[yi * width + xi] = .{ .r = 255 - @as(u8, @intFromFloat(@min(128, res.t))), .b = @as(u8, @intFromFloat(@min(128, res.t))), .g = 0 };
                hit_count += 1;
                avg_hit_t += res.t;
            } else {
                img.pixels.rgb24[yi * width + xi] = .{ .r = 0, .g = 30, .b = 0 };
                miss_count += 1;
            }
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
            \\ {d:.1} avg t (hits)
            \\ 
        , .{
            100 * hit_count / @as(f32, @floatFromInt(width * height)),
            100 * oob_count / @as(f32, @floatFromInt(width * height)),
            100 * miss_count / @as(f32, @floatFromInt(width * height)),
            avg_hit_t,
        });
    }
    try img.writeToFilePath("out.png", .{ .png = .{} });
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
