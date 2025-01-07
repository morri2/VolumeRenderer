const Self = @This();
const geo = @import("geo.zig");
const std = @import("std");
const Data = @import("Data.zig");

const SPACESIZE = @import("typedef.zig").SPACESIZE;
const ISOVAL = @import("typedef.zig").ISOVAL;

pub const SlimNode = packed struct {
    density_range: geo.Range(ISOVAL),
    partition: SPACESIZE, // cell >= partition means it is in left child
};

root_dim: [3]SPACESIZE,
root_space: geo.Volume(SPACESIZE),
nodes: []SlimNode,
allocator: std.mem.Allocator,
data: *const Data,

// ////////// //
// INDEX MATH //
// ////////// //
pub fn left(i: u32) u32 {
    return 2 * i + 1;
}

pub fn right(i: u32) u32 {
    return 2 * i + 2;
}

pub fn parent(i: u32) u32 {
    return (i - 1) / 2;
}

/// TODO
pub fn zoom(self: Self, idx: u32, node_space: *geo.Volume(SPACESIZE), partition_axis: geo.Axis, cell: geo.Cell) u32 {
    const node: SlimNode = self.nodes[idx];

    if (cell.arr[partition_axis.idx()] < node.partition) {
        node_space = node_space.splitInternal(node);
        return left(idx);
    } else {
        return right(idx);
    }
}

pub const SpaceTracker = struct {
    kdt: *const Self,
    node_space: geo.Volume(SPACESIZE),
    node_idx: u32 = 0,
    next_split_axis: geo.Axis = .X,
    layer: u32 = 0,

    pub fn new(kdt: *const Self) @This() {
        return .{
            .kdt = kdt,
            .node_space = geo.Volume(SPACESIZE).new(
                .{ 0, kdt.root_dim[0] },
                .{ 0, kdt.root_dim[1] },
                .{ 0, kdt.root_dim[2] },
            ),
        };
    }

    pub fn leftHalf(self: @This()) @This() {
        var out = self;
        out.node_space = self.node_space.splitGlobal(
            self.next_split_axis,
            self.kdt.nodes[self.node_idx].partition,
        )[0];
        out.node_idx = left(self.node_idx);

        out.layer += 1;
        out.next_split_axis = self.next_split_axis.next();
        return out;
    }

    pub fn rightHalf(self: @This()) @This() {
        var out = self;
        out.node_space = self.node_space.splitGlobal(
            self.next_split_axis,
            self.kdt.nodes[self.node_idx].partition,
        )[1];
        out.node_idx = right(self.node_idx);

        out.layer += 1;
        out.next_split_axis = self.next_split_axis.next();
        return out;
    }

    pub fn zoom(self: *@This(), cell: geo.Cell) void {
        const split_space = self.node_space.splitGlobal(self.next_split_axis, self.kdt.nodes[self.node_idx].partition);
        if (cell.arr[self.next_split_axis.idx()] < self.kdt.nodes[self.node_idx].partition) {
            self.node_space = split_space[0];
            self.node_idx = left(self.node_idx);
        } else {
            self.node_space = split_space[1];
            self.node_idx = right(self.node_idx);
        }
        self.layer += 1;
        self.next_split_axis = self.next_split_axis.next();
    }

    pub fn reset(self: *@This()) void {
        self.node_space = geo.Volume(SPACESIZE).new(
            .{ 0, self.kdt.root_dim[0] },
            .{ 0, self.kdt.root_dim[1] },
            .{ 0, self.kdt.root_dim[2] },
        );

        self.node_idx = 0;
        self.next_split_axis = .X;
        self.layer = 0;
    }
};

pub const RayRes = struct {
    t: f32 = 0,
    hit: bool = false,
    oob: bool = false,
    escape_help_count: f32 = 0,
    enter_vol_t: f32 = 0,
    checked_nodes: u64 = 0,
};

pub fn traceRay(ray: geo.Ray, kdt: *const Self, isoval: ISOVAL, comptime dbp: bool) RayRes {
    var t: f32 = 0.0;
    var escape_help_count: f32 = 0;
    var st = SpaceTracker.new(kdt);

    const do = ray.dir.gtz().cell().?; // to keep track of which planes we need to intersect with

    var checked_nodes: u64 = 0;

    // SHMOOVE US INTO THE SPACE
    const outer_planes = st.node_space.planes();
    t = @max(t, outer_planes[1 - do.x()].rayIntersect(ray));
    t = @max(t, outer_planes[3 - do.y()].rayIntersect(ray));
    t = @max(t, outer_planes[5 - do.z()].rayIntersect(ray));
    t += 0.001; // mini offset

    if (comptime dbp)
        std.debug.print(
            \\ 
            \\
            \\ ### NEW RAY ### 
            \\d= ({d:.2} {d:.2} {d:.2})  o= ({d:.2} {d:.2} {d:.2})
            \\skip to ({d:.2} {d:.2} {d:.2}) t={d:.3}
            \\
        , .{
            ray.dir.x,      ray.dir.y,      ray.dir.z,
            ray.origin.x,   ray.origin.y,   ray.origin.z,
            ray.point(t).x, ray.point(t).y, ray.point(t).z,
            t,
        });

    if (!st.node_space.containsFloat(ray.point(t))) {
        if (comptime dbp) std.debug.print(
            \\
            \\ oob
            \\ 
            \\
        , .{});
        return .{ .oob = true };
    }

    var cell = ray.point(t).cell().?;
    const enter_vol_t = t;

    while (st.node_space.containsFloat(ray.point(t))) {
        checked_nodes += 1;
        cell = ray.point(t).cell().?;
        if (comptime dbp)
            std.debug.print(
                \\ 
                \\t={d:.3}  r=({d:.2} {d:.2} {d:.2})
                \\node={}   size={}   iso=[{}-{}] v {}
                \\  res: 
            , .{
                t,           ray.point(t).x,       ray.point(t).y,                           ray.point(t).z,
                st.node_idx, st.node_space.size(), kdt.nodes[st.node_idx].density_range.min, kdt.nodes[st.node_idx].density_range.max,
                isoval,
            });

        // ZOOM if isovalue is in range
        if (kdt.nodes[st.node_idx].density_range.containsInclusive(isoval)) {
            if (st.node_space.size() == 1) {
                if (comptime dbp)
                    std.debug.print("HIT!\n", .{});
                return .{
                    .t = t,
                    .hit = true,
                    .escape_help_count = escape_help_count,
                    .enter_vol_t = enter_vol_t,
                    .checked_nodes = checked_nodes,
                }; // We have found a leaf node with relevant iso_value
            } else {
                if (comptime dbp)
                    std.debug.print("ZOOM!\n", .{});
                st.zoom(cell);
                continue; // ZOOM in
            }
        }

        // MOVE if
        if (comptime dbp)
            std.debug.print("MOVE!\n", .{});
        const planes = st.node_space.planes();
        t = std.math.inf(f32);

        t = @min(t, planes[0 + do.x()].rayIntersect(ray));
        t = @min(t, planes[2 + do.y()].rayIntersect(ray));
        t = @min(t, planes[4 + do.z()].rayIntersect(ray));
        t += 0.0001; // mini offset

        if (comptime dbp)
            if (st.node_space.containsFloat(ray.point(t))) {
                std.debug.print(
                    \\
                    \\VOLUME NOT ESQd!!!
                    \\x: {} {}
                    \\y: {} {}
                    \\z: {} {}
                    \\
                    \\
                , .{
                    st.node_space.xrange.min,
                    st.node_space.xrange.max,
                    st.node_space.yrange.min,
                    st.node_space.yrange.max,
                    st.node_space.zrange.min,
                    st.node_space.zrange.max,
                });
                std.debug.print("previous node not escaped!\n t={d} ({d} {d} {d})\n", .{
                    t,
                    ray.point(t).x,
                    ray.point(t).y,
                    ray.point(t).z,
                });
            };

        // escape help
        var i: f32 = 0;
        while (st.node_space.containsFloat(ray.point(t))) {
            t += 0.001 * i; // mini offset
            if (i > 1) {
                std.debug.print("!escape help needed! \n", .{});
            }
            i += 1;
            escape_help_count += 1;
        }

        std.debug.assert(!st.node_space.containsFloat(ray.point(t))); // we must have moved outside the thing, otherwise bad...

        st.reset(); // return to root
    }
    return .{
        .t = t,
        .hit = false,
        .escape_help_count = escape_help_count,
        .enter_vol_t = enter_vol_t,
        .checked_nodes = checked_nodes,
    };
}

pub fn saveToFile(self: Self) !void {
    _ = self; // autofix

}

/////// BUILD A TREE
pub fn init(data: *Data, allocator: std.mem.Allocator) Self {
    const kdt: Self = .{
        .root_dim = .{
            @intCast(data.resulution[0] - 1),
            @intCast(data.resulution[1] - 1),
            @intCast(data.resulution[2] - 1),
        },
        .root_space = geo.Volume(SPACESIZE).new(
            .{ 0, @intCast(data.resulution[0] - 1) },
            .{ 0, @intCast(data.resulution[1] - 1) },
            .{ 0, @intCast(data.resulution[2] - 1) },
        ),
        .nodes = allocator.alloc(SlimNode, data.size() * 2) catch unreachable,
        .allocator = allocator,
        .data = data,
    };
    return kdt;
}

// EVEN PARTITION
pub fn newEvenPartition(data: *Data) Self {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var kdt: Self = init(data, gpa.allocator());
    const st = SpaceTracker.new(&kdt);

    std.debug.print("Building new tree: {d} nodes len\n", .{kdt.nodes.len});

    newEvenPartitionInner(&kdt, data, st);
    std.debug.print("Building new tree: {d} nodes len\n", .{kdt.nodes.len});
    std.debug.print("layers: {}\n", .{max_layer});
    return kdt;
}

pub fn newEvenPartitionInner(kdt: *Self, data: *Data, st: SpaceTracker) void {
    var min_d: ISOVAL = std.math.maxInt(ISOVAL);
    var max_d: ISOVAL = 0;

    if (st.node_space.size() < 1) {
        return;
    }

    if (st.node_idx >= kdt.nodes.len) {
        kdt.nodes = kdt.allocator.realloc(kdt.nodes, (kdt.nodes.len * @sizeOf(SlimNode)) << 2) catch @panic("not enough mem");
        std.debug.print("REALLOCING!!!!!\n\n\n", .{});
    }

    if (st.layer > max_layer) max_layer = st.layer;

    var iter = st.node_space.initIterator();
    while (iter.next()) |c| {
        for (data.getCornerDens(c)) |v| {
            min_d = @min(min_d, v);
            max_d = @max(max_d, v);
        }
    }

    const partition: u8 = @intCast(( //
        @as(u32, @intCast(st.node_space.getAxisRange(st.next_split_axis).min)) + //
        @as(u32, @intCast(st.node_space.getAxisRange(st.next_split_axis).max))) / 2);
    //std.debug.print("\nspace {} \n", .{st.node_space.size()});
    kdt.nodes[st.node_idx] = .{
        .partition = partition,
        .density_range = geo.Range(ISOVAL).new(
            min_d,
            max_d,
        ),
    };

    if (st.node_space.size() == 1) {
        return;
    }

    newEvenPartitionInner(kdt, data, st.leftHalf());
    newEvenPartitionInner(kdt, data, st.rightHalf());
}

// EVEN PARTITION
pub fn newSlantedPartition(data: *Data) Self {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var kdt: Self = init(data, gpa.allocator());
    const st = SpaceTracker.new(&kdt);

    std.debug.print("Building new tree: {d} nodes len\n", .{kdt.nodes.len});

    newSlantedPartitionInner(&kdt, data, st);
    std.debug.print("Building new tree: {d} nodes len\n", .{kdt.nodes.len});

    std.debug.print("layers: {}\n", .{max_layer});
    return kdt;
}

var layer_densities: [1024]struct { min: ISOVAL = std.math.maxInt(ISOVAL), max: ISOVAL = 0 } = undefined;
var max_layer: u32 = 0;

pub fn newSlantedPartitionInner(kdt: *Self, data: *Data, st: SpaceTracker) void {
    if (st.node_space.size() < 1)
        return;

    if (st.layer > max_layer) max_layer = st.layer;

    if (st.node_idx >= kdt.nodes.len) {
        kdt.nodes = kdt.allocator.realloc(kdt.nodes, (kdt.nodes.len * @sizeOf(SlimNode)) << 2) catch @panic("not enough mem");
        std.debug.print("REALLOCING!!!!!\n\n\n", .{});
    }

    var min_d: ISOVAL = std.math.maxInt(ISOVAL);
    var max_d: ISOVAL = 0;

    layer_densities = .{.{}} ** 1024;

    var iter = st.node_space.initIterator();
    while (iter.next()) |c| {
        for (data.getCornerDens(c)) |v| {
            min_d = @min(min_d, v);
            max_d = @max(max_d, v);

            layer_densities[c.arr[st.next_split_axis.idx()]].min = @min(layer_densities[c.arr[st.next_split_axis.idx()]].min, v);
            layer_densities[c.arr[st.next_split_axis.idx()]].max = @max(layer_densities[c.arr[st.next_split_axis.idx()]].max, v);
        }
    }
    const mid_partition: u8 = @intCast(( //
        @as(u32, @intCast(st.node_space.getAxisRange(st.next_split_axis).min)) + //
        @as(u32, @intCast(st.node_space.getAxisRange(st.next_split_axis).max))) / 2);
    var best_partition: u8 = mid_partition;

    var best_heuristic: f32 = 9999999.9;

    const p_low: u8 = @intCast(( //
        @as(u32, @intCast(st.node_space.getAxisRange(st.next_split_axis).min)) + //
        @as(u32, @intCast(mid_partition))) / 2);
    const p_high: u8 = @intCast(( //
        @as(u32, @intCast(st.node_space.getAxisRange(st.next_split_axis).max)) + //
        @as(u32, @intCast(mid_partition))) / 2);

    // OPTIM
    if (st.node_space.getAxisRange(st.next_split_axis).min + 1 < st.node_space.getAxisRange(st.next_split_axis).max and max_layer < 16) {
        for (p_low..p_high) |p_cand| {
            // MIN SQUARE SUM
            var left_max: f32 = 0;
            var left_min: f32 = std.math.inf(f32);

            var right_max: f32 = 0;
            var right_min: f32 = std.math.inf(f32);

            for (st.node_space.getAxisRange(st.next_split_axis).min..p_cand) |i| {
                left_max = @max(left_max, @as(f32, @floatFromInt(layer_densities[i].max)));
                left_min = @min(left_min, @as(f32, @floatFromInt(layer_densities[i].min)));
            }

            for (p_cand..st.node_space.getAxisRange(st.next_split_axis).max) |i| {
                right_max = @max(right_max, @as(f32, @floatFromInt(layer_densities[i].max)));
                right_min = @min(right_min, @as(f32, @floatFromInt(layer_densities[i].min)));
            }

            const h_cand = std.math.pow(f32, (right_max - right_min), 2) + std.math.pow(f32, (left_max - left_min), 2) //
            + @abs(@as(f32, @floatFromInt(p_cand)) - @as(f32, @floatFromInt(mid_partition)));

            //std.debug.print("  pcand {}  h={d:.2},\n", .{ p_cand, h_cand });
            if (h_cand < best_heuristic) {
                best_partition = @intCast(p_cand);
                best_heuristic = h_cand;
            }
        }
    }

    //std.debug.print("\nspace {} \n", .{st.node_space.size()});
    kdt.nodes[st.node_idx] = .{
        .partition = best_partition,
        .density_range = geo.Range(ISOVAL).new(
            min_d,
            max_d,
        ),
    };

    if (st.node_space.size() == 1) {
        return;
    }

    //std.debug.print("split l={}, partition: {} | {} | {}                 maxlayer: {}\n", .{
    //    st.layer,
    //    st.node_space.getAxisRange(st.next_split_axis).min,
    //    best_partition,
    //    st.node_space.getAxisRange(st.next_split_axis).max,
    //    max_layer,
    //});

    newSlantedPartitionInner(kdt, data, st.leftHalf());
    newSlantedPartitionInner(kdt, data, st.rightHalf());
}
