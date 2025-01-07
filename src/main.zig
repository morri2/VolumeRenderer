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

// pub fn skullRenderBM(allocator: std.mem.Allocator) void {
//     var img = zigimg.Image.create(allocator, 1000, 1000, .rgb24) catch @panic("test alloc");
//     defer img.deinit();

//     const data_center = geo.Vec3(f32).new(
//         @floatFromInt(GLOBAL_skull_data.resulution[0] / 2),
//         @floatFromInt(GLOBAL_skull_data.resulution[1] / 2),
//         @floatFromInt(GLOBAL_skull_data.resulution[2] / 2),
//     );

//     const camera_pos = geo.Vec3(f32).new(-30, -300, -30);
//     const camera_dir = data_center.sub(camera_pos).norm();

//     var c = camera_dir;
//     c = c.cross(geo.Vec3(f32).new(0.0, 1.0, 0.0));
//     c = c.cross(camera_dir);
//     const camera_up = c;
//     for (0..256) |i| {
//         slimRTimg(
//             camera_pos,
//             data_center.sub(camera_pos).norm(),
//             camera_up,
//             &img,
//             2.0,
//             GLOBAL_skull_kdt,
//             i,
//             false,
//             false,
//         ) catch @panic("test render");
//     }
// }

pub fn main() !void {
    var data = try Data.loadUCD("Skull.vol", .{ .swap_x_y = true });

    for (0..data.resulution[0]) |x| {
        for (0..data.resulution[0]) |y| {
            for (0..data.resulution[0]) |z| {
                data.set(0, @intCast(x), @intCast(y), @intCast(z));
                if (x == 60 and y == 60 and z == 60) {
                    data.set(255, @intCast(x), @intCast(y), @intCast(z));
                }
            }
        }
    }

    // for (60..data.resulution[0]) |x| {
    //     for (250..data.resulution[0]) |y| {
    //         for (250..data.resulution[0]) |z| {
    //             data.set(255, @intCast(x), @intCast(y), @intCast(z));
    //         }
    //     }
    // }

    const kdt = SlimKDT.newEvenPartition(&data);
    //const kdt = SlimKDT.newSlantedPartition(&data);

    GLOBAL_skull_data = &data;
    GLOBAL_skull_kdt = &kdt;

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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var node_checks: u64 = 0;
    for (0..256) |i| {
        var img = try zigimg.Image.create(allocator, 500, 500, .rgb24);
        defer img.deinit();

        var buf: [64]u8 = undefined;
        const file_name = std.fmt.bufPrint(&buf, "renders/out_iso{d}.png", .{i}) catch unreachable;
        std.debug.print("\n{s}\n", .{buf});

        const start_time_img = std.time.milliTimestamp();

        const res = try raytrace.renderImage(
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
        node_checks += res.nodes_checked;
        const end_time_img = std.time.milliTimestamp();

        tot_time += end_time_img - start_time_img;

        try img.writeToFilePath(file_name, .{ .png = .{} });
    }

    const end_time = std.time.milliTimestamp();

    std.debug.print("RT end... {}ms\n", .{end_time - start_time});
    std.debug.print("node checks: {}\n", .{node_checks});
    std.debug.print("Render time per img: {d}ms \n", .{@as(f32, @floatFromInt(tot_time)) / 256});
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
