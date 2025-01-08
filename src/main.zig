const std = @import("std");
//const KDtree = @import("KDtree.zig");
const Data = @import("Data.zig");
const zigimg = @import("zigimg");
const raytrace = @import("raytrace.zig");
const geo = @import("geo.zig");
const SlimKDT = @import("SlimKDT.zig");
const ISOVAL = @import("typedef.zig").ISOVAL;
const zbench = @import("zbench");

pub fn main() !void {
    //const dataset_name = "Skull.vol";
    const dataset_name = "C60.vol";

    std.debug.print("Loading dataset: '{s}'\n", .{dataset_name});
    var data = try Data.loadUCD(dataset_name);

    //const kdt = SlimKDT.newHeursiticPartition(&data, SlimKDT.AlwaysCenterH);
    var kdt: SlimKDT = undefined; // try SlimKDT.newHeursiticPartition(&data, SlimKDT.MixLeafsideH);

    //const kdt = SlimKDT.newSlantedPartition(&data);

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

    // std.debug.print(
    //     \\
    //     \\
    //     \\ Raytracing
    //     \\ camera: ({d:.2} {d:.2} {d:.2})
    //     \\ facing: ({d:.2} {d:.2} {d:.2})
    //     \\ up:     ({d:.2} {d:.2} {d:.2})
    //     \\
    //     \\
    //     \\
    // , .{ camera_pos.x, camera_pos.y, camera_pos.z, camera_dir.x, camera_dir.y, camera_dir.z, camera_up.x, camera_up.y, camera_up.z });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const heuristics = .{
        SlimKDT.AlwaysCenterH,
        SlimKDT.FlexibleFirst5,
        //SlimKDT.FlexibleFirst10,

        //SlimKDT.FlexibleAfter10,
        SlimKDT.FlexibleAfter15,
        SlimKDT.FlexibleAfter20,

        //SlimKDT.FlexibleCenterWeighted5,
        //SlimKDT.FlexibleCenterWeighted10,
        SlimKDT.FlexibleCenterWeighted30,
        SlimKDT.FlexibleCenterWeighted50,
        SlimKDT.FlexibleCenterWeighted75,
        //SlimKDT.FlexibleCenterWeighted100,
    };

    const heuristics_name = .{
        "AlwaysCenter",
        "FlexibleFirst5",
        //"FlexibleFirst10",

        //"FlexibleAfter10",
        "FlexibleAfter15",
        "FlexibleAfter20",

        //"FlexibleCenterWeigthed5",
        //"FlexibleCenterWeigthed10",
        "FlexibleCenterWeigthed30",
        "FlexibleCenterWeigthed50",
        "FlexibleCenterWeigthed75",
        //"FlexibleCenterWeigthed100",
    };

    var tot_time_balanced: i64 = 0;

    inline for (comptime heuristics, 0..) |Hfn, hi| {
        std.debug.print("\n\nBUILDING KDT WITH HEURISTIC {s}\n\n", .{heuristics_name[hi]});
        var ok = true;
        blk: {
            kdt = SlimKDT.newHeursiticPartition(&data, Hfn) catch {
                std.debug.print("\n FAILD TO BUILD KDT!\n", .{});
                ok = false;
                break :blk;
            };
        }

        if (ok) { // only if we actuall built the kdt
            var tot_time: i64 = 0.0;
            defer kdt.deinit();
            var node_checks: u64 = 0;
            for (0..256) |i| {
                var img = try zigimg.Image.create(allocator, 512, 512, .rgb24);
                defer img.deinit();

                var buf: [64]u8 = undefined;
                const file_name = std.fmt.bufPrint(&buf, "renders/out_iso{d}.png", .{i}) catch unreachable;
                //std.debug.print("\n{s}\n", .{file_name});

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

            if (hi == 0) {
                tot_time_balanced = tot_time;
            }

            std.debug.print("node checks: {}  ({} million)\n", .{ node_checks, @divFloor(node_checks, 1_000_000) });
            std.debug.print("Render time per img: {d}ms \n", .{@as(f32, @floatFromInt(tot_time)) / 256});

            std.debug.print(
                \\ 
                \\
                \\(ms/frame)	(layers)	(deviating partitions)	(nodes checked [mil]) (time per frame vs balanced)
                \\      {d} ,            {} ,                  {} ,            {} ,                 {d}
                \\
                \\
                \\
            , .{
                @as(f32, @floatFromInt(tot_time)) / 256,
                SlimKDT.PARTITION_BUILD_DATA_OUT.layer_count,
                SlimKDT.PARTITION_BUILD_DATA_OUT.non_center_partition_count,
                @divFloor(node_checks, 1_000_000),
                @as(f32, @floatFromInt(tot_time)) / @as(f32, @floatFromInt(tot_time_balanced)),
            });
        }
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
