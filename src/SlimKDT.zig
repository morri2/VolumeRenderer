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
nodes: [256 * 256 * 256]SlimNode,

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
            self.node_space = split_space[1];
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

pub fn traceRay(ray: geo.Ray, kdt: *const Self, isoval: ISOVAL) bool {
    var t: f32 = 0.0;
    var st = SpaceTracker.new(kdt);

    const do = ray.dir.gtz().cell().?; // to keep track of which planes we need to intersect with

    while (st.node_space.containsFloat(ray.point(t))) {
        // ZOOM if isovalue is in range
        if (kdt.nodes[st.node_idx].density_range.contains(isoval)) {
            if (st.node_space.size() == 0) {
                return true; // We have found a leaf node with relevant iso_value
            } else {
                st.zoom(ray.point(t).cell().?);
                continue; // ZOOM in
            }
        }

        // MOVE if
        const planes = st.node_space.planes();
        t = std.math.inf(f32);

        t = @min(t, planes[0 + do.vec.x].rayIntersect(ray));
        t = @min(t, planes[2 + do.vec.y].rayIntersect(ray));
        t = @min(t, planes[4 + do.vec.z].rayIntersect(ray));
        t += 0.00001; // mini offset

        std.debug.assert(!st.node_space.containsFloat(ray.point(t))); // we must have moved outside the thing, otherwise bad...
        st.reset(); // return to root
    }
    return false;
}

/////// BUILD A TREE

pub fn newEvenPartition(data: *Data) Self {
    var kdt: Self = .{
        .root_dim = .{
            @intCast(data.resulution[0]),
            @intCast(data.resulution[1]),
            @intCast(data.resulution[2]),
        },
        .root_space = geo.Volume(SPACESIZE).new(
            .{ 0, @intCast(data.resulution[0]) },
            .{ 0, @intCast(data.resulution[1]) },
            .{ 0, @intCast(data.resulution[2]) },
        ),
        .nodes = undefined,
    };
    const st = SpaceTracker.new(&kdt);

    newEvenPartitionInner(&kdt, data, st);

    return kdt;
}

pub fn newEvenPartitionInner(kdt: *Self, data: *Data, st: SpaceTracker) void {
    var min_d: ISOVAL = std.math.maxInt(ISOVAL);
    var max_d: ISOVAL = 0;

    var iter = st.node_space.initIterator();
    while (iter.next()) |s| {
        const v = data.get(s.x, s.y, s.z);
        min_d = @min(min_d, v);
        max_d = @max(max_d, v);
    }

    const partition = (st.node_space.getAxisRange(st.next_split_axis).min + st.node_space.getAxisRange(st.next_split_axis).max) / 2;

    kdt.nodes[st.node_idx] = .{
        .partition = partition,
        .density_range = geo.Range(ISOVAL).new(
            min_d,
            max_d,
        ),
    };

    newEvenPartitionInner(kdt, data, st.leftHalf());
    newEvenPartitionInner(kdt, data, st.rightHalf());
}
