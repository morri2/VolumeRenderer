const Self = @This();
const geo = @import("geo.zig");
const std = @import("std");
const Data = @import("Data.zig");

const SPACESIZE = @import("typedef.zig").SPACESIZE;
const ISOVAL = @import("typedef.zig").ISOVAL;

pub const SlimNode = packed struct {
    density_range: geo.Range(ISOVAL),
    partition: SPACESIZE, // cell >= partition means it is in left child
    axis: geo.Axis,
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
    //next_split_axis: geo.Axis = .X,
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
            self.node_space.largestDim(),
            self.kdt.nodes[self.node_idx].partition,
        )[0];
        out.node_idx = left(self.node_idx);
        out.layer += 1;

        return out;
    }

    pub fn rightHalf(self: @This()) @This() {
        var out = self;
        out.node_space = self.node_space.splitGlobal(
            self.node_space.largestDim(),
            self.kdt.nodes[self.node_idx].partition,
        )[1];
        out.node_idx = right(self.node_idx);
        out.layer += 1;

        return out;
    }

    pub fn zoom(self: *@This(), cell: geo.Cell) void {
        const split_space = self.node_space.splitGlobal(
            self.kdt.nodes[self.node_idx].axis,
            self.kdt.nodes[self.node_idx].partition,
        );
        if (cell.arr[self.kdt.nodes[self.node_idx].axis.idx()] < self.kdt.nodes[self.node_idx].partition) {
            self.node_space = split_space[0];
            self.node_idx = left(self.node_idx);
        } else {
            self.node_space = split_space[1];
            self.node_idx = right(self.node_idx);
        }
        self.layer += 1;
    }

    pub fn reset(self: *@This()) void {
        self.node_space = geo.Volume(SPACESIZE).new(
            .{ 0, self.kdt.root_dim[0] },
            .{ 0, self.kdt.root_dim[1] },
            .{ 0, self.kdt.root_dim[2] },
        );

        self.node_idx = 0;
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

pub fn deinit(self: *Self) void {
    self.allocator.free(self.nodes);
}

// EVEN PARTITION
pub fn newEvenPartition(data: *Data) Self {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var kdt: Self = init(data, gpa.allocator());
    const st = SpaceTracker.new(&kdt);

    std.debug.print("Building new tree: {d} nodes len\n", .{kdt.nodes.len});

    newEvenPartitionInner(&kdt, data, st);
    std.debug.print("Building new tree: {d} nodes len\n", .{kdt.nodes.len});

    return kdt;
}

pub fn newEvenPartitionInner(kdt: *Self, data: *Data, st: SpaceTracker) void {
    var min_d: ISOVAL = std.math.maxInt(ISOVAL);
    var max_d: ISOVAL = 0;

    if (st.node_space.size() < 1) {
        return;
    }

    const next_split_axis = st.node_space.largestDim();

    if (st.node_idx >= kdt.nodes.len) {
        kdt.nodes = kdt.allocator.realloc(kdt.nodes, (kdt.nodes.len * @sizeOf(SlimNode)) << 2) catch @panic("not enough mem");
        std.debug.print("REALLOCING!!!!!\n\n\n", .{});
    }

    // if (st.layer > max_layer) max_layer = st.layer;

    var iter = st.node_space.initIterator();
    while (iter.next()) |c| {
        for (data.getCornerDens(c)) |v| {
            min_d = @min(min_d, v);
            max_d = @max(max_d, v);
        }
    }

    const partition: u8 = @intCast(( //
        @as(u32, @intCast(st.node_space.getAxisRange(next_split_axis).min)) + //
        @as(u32, @intCast(st.node_space.getAxisRange(next_split_axis).max))) / 2);
    //std.debug.print("\nspace {} \n", .{st.node_space.size()});
    kdt.nodes[st.node_idx] = .{
        .partition = partition,
        .axis = next_split_axis,
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

///
///
///
///
///
pub const PartitionBuildData = struct {
    non_center_partition_count: u64 = 0,
    layer_count: u64 = 0,
    number_of_nodes: u64 = 0,
};

pub fn newHeursiticPartition(
    data: *Data,
    comptime Heuristic: fn (p: SPACESIZE, mid: SPACESIZE, st: SpaceTracker, axis: geo.Axis) f32,
) Self {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var kdt: Self = init(data, gpa.allocator());
    const st = SpaceTracker.new(&kdt);

    std.debug.print("Starting building tree...\n", .{});
    const r = newHeuristicPartitionInner(&kdt, data, st, Heuristic);
    std.debug.print(
        \\
        \\ KDT Built
        \\ nodes: {}
        \\ non center partitions: {}
        \\ layers: {} (deepest point)
        \\
    , .{ r.number_of_nodes, r.non_center_partition_count, r.layer_count });
    return kdt;
}

pub fn newHeuristicPartitionInner(
    kdt: *Self,
    data: *Data,
    st: SpaceTracker,
    comptime Heuristic: fn (p: SPACESIZE, mid: SPACESIZE, st: SpaceTracker, axis: geo.Axis) f32,
) PartitionBuildData {
    var min_d: ISOVAL = std.math.maxInt(ISOVAL);
    var max_d: ISOVAL = 0;

    if (st.node_space.size() < 1) {
        return .{};
    }
    if (st.layer > MAX_LAYER_SEEN) {
        MAX_LAYER_SEEN = st.layer;
    }

    const next_split_axis = st.node_space.largestDim();

    if (st.node_idx >= kdt.nodes.len) {
        kdt.nodes = kdt.allocator.realloc(kdt.nodes, (kdt.nodes.len * @sizeOf(SlimNode)) << 2) catch {
            std.debug.print("( layers so far: {} )", .{MAX_LAYER_SEEN});
            @panic("not enough mem");
        };

        std.debug.print("REALLOCING!!!!!\n\n\n", .{});
    }

    var iter = st.node_space.initIterator();
    while (iter.next()) |c| {
        for (data.getCornerDens(c)) |v| {
            min_d = @min(min_d, v);
            max_d = @max(max_d, v);
        }
    }
    const mid_partition: u8 = @intCast(( //
        @as(u32, @intCast(st.node_space.getAxisRange(next_split_axis).min)) + //
        @as(u32, @intCast(st.node_space.getAxisRange(next_split_axis).max))) / 2);

    var best_partition: u8 = mid_partition;
    var best_heuristic: f32 = std.math.inf(f32);

    for (st.node_space.getAxisRange(next_split_axis).min + 1..st.node_space.getAxisRange(next_split_axis).max) |partition_candidate_usize| {
        const partition_candidate: u8 = @intCast(partition_candidate_usize);

        const candidate_heuristic: f32 = Heuristic(partition_candidate, mid_partition, st, next_split_axis);

        if (best_heuristic > candidate_heuristic) {
            best_partition = partition_candidate;
            best_heuristic = candidate_heuristic;
        }
    }

    //std.debug.print("\nspace {} \n", .{st.node_space.size()});
    kdt.nodes[st.node_idx] = .{
        .partition = best_partition,
        .axis = next_split_axis,
        .density_range = geo.Range(ISOVAL).new(
            min_d,
            max_d,
        ),
    };

    if (st.node_space.size() == 1) {
        return .{ .number_of_nodes = 1, .layer_count = st.layer };
    }

    const r1 = newHeuristicPartitionInner(kdt, data, st.leftHalf(), Heuristic);
    const r2 = newHeuristicPartitionInner(kdt, data, st.rightHalf(), Heuristic);

    return .{
        .non_center_partition_count = r1.non_center_partition_count + r2.non_center_partition_count + @intFromBool(mid_partition != best_partition),
        .layer_count = @max(r1.layer_count, @max(r2.layer_count, st.layer)),
        .number_of_nodes = r1.number_of_nodes + r2.number_of_nodes + 1,
    };
}
// crash logging
var MAX_LAYER_SEEN: u32 = 0;

// smaller is better
pub fn MinimizeSpanHeuristic(p: SPACESIZE, mid: SPACESIZE, st: SpaceTracker, axis: geo.Axis) f32 {
    const halfs = st.node_space.splitGlobal(axis, p);

    var left_iter = halfs[0].initIterator();
    var right_iter = halfs[1].initIterator();

    var left_max: SPACESIZE = 0;
    var left_min: SPACESIZE = std.math.maxInt(SPACESIZE);

    var right_max: SPACESIZE = 0;
    var right_min: SPACESIZE = std.math.maxInt(SPACESIZE);

    while (left_iter.next()) |c| {
        const cdr = st.kdt.data.getCornerDensRange(c);
        left_min = @min(left_min, cdr.min);
        left_max = @max(left_max, cdr.max);
    }

    while (right_iter.next()) |c| {
        const cdr = st.kdt.data.getCornerDensRange(c);
        right_min = @min(right_min, cdr.min);
        right_max = @max(right_max, cdr.max);
    }

    var h: f32 = 0;
    h += @abs(@as(f32, @floatFromInt(p)) - @as(f32, @floatFromInt(mid))); // penalty for deviation from mid
    h += @abs(@as(f32, @floatFromInt(left_max)) - @as(f32, @floatFromInt(left_min))); // penalty for range of isovalues on left side
    h += @abs(@as(f32, @floatFromInt(right_max)) - @as(f32, @floatFromInt(right_min))); // penalty for range of isovalues on right side

    return h;
}

pub fn AlwaysCenterH(p: SPACESIZE, mid: SPACESIZE, st: SpaceTracker, axis: geo.Axis) f32 {
    _ = st; // autofix
    _ = axis; // autofix
    if (p == mid) {
        return 0;
    } else {
        return 1;
    }
}

pub fn MixRootsideH(p: SPACESIZE, mid: SPACESIZE, st: SpaceTracker, axis: geo.Axis) f32 {
    if (st.layer > 16) {
        return AlwaysCenterH(p, mid, st, axis);
    } else {
        return MinimizeSpanHeuristic(p, mid, st, axis);
    }
}

pub fn MixLeafsideH(p: SPACESIZE, mid: SPACESIZE, st: SpaceTracker, axis: geo.Axis) f32 {
    if (st.layer < 16) {
        return AlwaysCenterH(p, mid, st, axis);
    } else {
        return MinimizeSpanHeuristic(p, mid, st, axis);
    }
}
