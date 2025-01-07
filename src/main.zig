const std = @import("std");
//const KDtree = @import("KDtree.zig");
const Data = @import("Data.zig");
const zigimg = @import("zigimg");
const raytrace = @import("raytrace.zig");
const geo = @import("geo.zig");
const SlimKDT = @import("SlimKDT.zig");
const ISOVAL = @import("typedef.zig").ISOVAL;
const zbench = @import("zbench");

var GLOBAL_skull_data: *const Data = undefined;
var GLOBAL_skull_kdt: *const SlimKDT = undefined;
test "bench test" {

    // init data
    GLOBAL_skull_data = try Data.loadUCD("Skull.vol", .{ .swap_x_y = true });
    GLOBAL_skull_kdt = SlimKDT.newEvenPartition(&GLOBAL_skull_data);
}

pub fn skullRenderBM(allocator: std.mem.Allocator) void {
    var img = zigimg.Image.create(allocator, 1000, 1000, .rgb24) catch @panic("test alloc");
    defer img.deinit();

    const data_center = geo.Vec3(f32).new(
        @floatFromInt(GLOBAL_skull_data.resulution[0] / 2),
        @floatFromInt(GLOBAL_skull_data.resulution[1] / 2),
        @floatFromInt(GLOBAL_skull_data.resulution[2] / 2),
    );

    const camera_pos = geo.Vec3(f32).new(-30, -300, -30);
    const camera_dir = data_center.sub(camera_pos).norm();

    var c = camera_dir;
    c = c.cross(geo.Vec3(f32).new(0.0, 1.0, 0.0));
    c = c.cross(camera_dir);
    const camera_up = c;
    for (0..256) |i| {
        slimRTimg(
            camera_pos,
            data_center.sub(camera_pos).norm(),
            camera_up,
            &img,
            2.0,
            GLOBAL_skull_kdt,
            i,
            false,
            false,
        ) catch @panic("test render");
    }
}

pub fn main() !void {
    std.debug.print("\n\nData: C60 (32x32x32) \n100x100px img  \nrender time 26050ms\n\n\n", .{});

    var data = try Data.loadUCD("Skull.vol", .{ .swap_x_y = true });
    data = data; // autofix

    //const kdt = SlimKDT.newEvenPartition(&data);
    const kdt = SlimKDT.newSlantedPartition(&data);

    GLOBAL_skull_data = &data;
    GLOBAL_skull_kdt = &kdt;

    // var bench = zbench.Benchmark.init(
    //     std.heap.page_allocator,
    //     .{},
    // );
    // defer bench.deinit();
    // try bench.add("Skull 1000^2", skullRenderBM, .{});
    // try bench.run(std.io.getStdOut().writer());

    const data_center = geo.Vec3(f32).new(
        @floatFromInt(data.resulution[0] / 2),
        @floatFromInt(data.resulution[1] / 2),
        @floatFromInt(data.resulution[2] / 2),
    );

    const camera_pos = geo.Vec3(f32).new(-30, -300, -30);
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

    var tot_time: i64 = 0.0;
    std.debug.print("RT start...\n", .{});
    const start_time = std.time.milliTimestamp();

    // for (0..256) |i| {
    //     var buf: [64:0]u8 = undefined;
    //     const file_name = std.fmt.bufPrint(&buf, "renders/out_iso{d}.png", .{i}) catch unreachable;
    //     std.debug.print("\n{s}\n", .{buf});
    //     try slimRT(
    //         camera_pos,
    //         data_center.sub(camera_pos).norm(),
    //         camera_up,
    //         1000,
    //         1000,
    //         2.0,
    //         kdt,
    //         @intCast(i),
    //         file_name,
    //         true,
    //         false,
    //     );
    // }

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    for (0..256) |i| {
        var img = try zigimg.Image.create(allocator, 500, 500, .rgb24);
        defer img.deinit();

        var buf: [64]u8 = undefined;
        const file_name = std.fmt.bufPrint(&buf, "renders/out_iso{d}.png", .{i}) catch unreachable;
        std.debug.print("\n{s}\n", .{buf});

        const start_time_img = std.time.milliTimestamp();

        try slimRTimg(
            camera_pos,
            data_center.sub(camera_pos).norm(),
            camera_up,
            &img,
            2.0,
            &kdt,
            @intCast(i),
            false,
            false,
        );
        const end_time_img = std.time.milliTimestamp();

        tot_time += end_time_img - start_time_img;

        try img.writeToFilePath(file_name, .{ .png = .{} });
    }

    const end_time = std.time.milliTimestamp();

    std.debug.print("RT end... {}ms\n", .{end_time - start_time});

    std.debug.print("Render time per img: {d}ms \n", .{@as(f32, @floatFromInt(tot_time)) / 256});
}

pub fn slimRTimg(
    src: geo.VecF,
    forw: geo.VecF,
    up: geo.VecF,
    img: *zigimg.Image,
    viewport_width: f32,
    kdt: *const SlimKDT,
    isoval: ISOVAL,
    comptime dbp: bool,
    comptime inner_dbp: bool,
) !void {
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
        , .{
            100 * hit_count / @as(f32, @floatFromInt(width * height)),
            100 * oob_count / @as(f32, @floatFromInt(width * height)),
            100 * miss_count / @as(f32, @floatFromInt(width * height)),
            avg_hit_t,
            min_hit_t,
            max_hit_t,
            escape_help_events,
        });
    }
}

pub fn quickImage(
    src: geo.VecF,
    forw: geo.VecF,
    up: geo.VecF,
    width: u32,
    height: u32,
    viewport_width: f32,
    kdt: *const SlimKDT,
    isoval: ISOVAL,
    comptime dbp: bool,
    comptime inner_dbp: bool,
) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const img = try zigimg.Image.create(allocator, width, height, .rgb24);

    return try raytrace.renderImage(src, forw, up, &img, viewport_width, kdt, isoval, dbp, inner_dbp);
}
