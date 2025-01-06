const std = @import("std");

const geo = @import("geo.zig");
const Data = @import("Data.zig");

const Self = @This();
const MAX_INNER_NODES: comptime_int = 425540;
pub const ROOT = 0;

const SPACESIZE = @import("typedef.zig").SPACESIZE;
const ISOVAL = @import("typedef.zig").ISOVAL;

nodes: [MAX_INNER_NODES]Node = undefined,

const Node = packed struct {
    leaf: bool,
    space: geo.Volume(SPACESIZE),
    dens_range: geo.Range(u8),
};

pub fn zoom(self: Self, idx: u32, cell: geo.Cell) ?u32 {
    if (self.nodes[idx].leaf) return null;
    if (self.nodes[left(idx)].space.contains(cell)) {
        return left(idx);
    } else {
        return right(idx);
    }
}

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

pub fn binaryPartionFromData(data: *Data) Self {
    var tree: Self = .{};
    binaryPartionFromDataInner(&tree, 0, data, geo.Volume(SPACESIZE).new(
        .{ 0, @intCast(data.resulution[0]) },
        .{ 0, @intCast(data.resulution[1]) },
        .{ 0, @intCast(data.resulution[2]) },
    ), 0);
    return tree;
}

pub fn binaryPartionFromDataInner(self: *Self, idx: u32, data: *Data, space: geo.Volume(SPACESIZE), layer: u8) void {
    const is_leaf = space.size() <= 1;

    //std.debug.print("new node with dims: {} {} {}\n", .{ space.xrange.len(), space.yrange.len(), space.zrange.len() });

    self.nodes[idx] = .{
        .leaf = is_leaf,
        .space = space,
        .dens_range = geo.Range(ISOVAL).new(0, 9),
    };

    var iter = space.initIterator();

    while (iter.next()) |cell| {
        const val = data.get(cell.x, cell.y, cell.z);
        self.nodes[idx].dens_range.max = @max(self.nodes[idx].dens_range.max, val);
        self.nodes[idx].dens_range.min = @min(self.nodes[idx].dens_range.min, val);
    }

    if (is_leaf) return;

    const subspace = space.splitMiddle(space.largestDim());

    if (space.size() <= subspace[0].size()) std.debug.print("WAAAA!!!!!!\n\n", .{});
    if (space.size() <= subspace[1].size()) std.debug.print("WAAAA!!!!!!!!!!!!\n\n", .{});

    binaryPartionFromDataInner(self, left(idx), data, subspace[0], layer + 1);
    binaryPartionFromDataInner(self, right(idx), data, subspace[1], layer + 1);
}

// ///////////////// //
// STUFF FOR TESTING //
// ///////////////// //

// pub fn newTestTree() Self {
//     var tree: Self = .{};
//     tree.newTestTreeInner(ROOT, 0);
//     return tree;
// }

// pub fn newTestTreeInner(self: *Self, idx: u32, level: u32) void {
//     const is_leaf = level >= 3;
//     self.nodes[idx] = .{
//         .leaf = is_leaf,
//         .space = .{.xrange = , .{ 0, 3 }, .{ 0, 3 }),
//         .dens_range = geo.Range(u8).new(0, 0),
//     };
//     if (self.nodes[idx].leaf) {
//         return;
//     }
//     self.newTestTreeInner(left(idx), level + 1);
//     self.newTestTreeInner(right(idx), level + 1);
// }

pub fn printTree(self: Self) void {
    self.printTreeInner(ROOT, 0);
}

pub fn printTreeInner(self: Self, idx: u32, indents: u32) void {
    for (0..indents) |_| std.debug.print("| ", .{});
    std.debug.print("node{d}\n", .{idx});
    if (self.nodes[idx].leaf) {
        return;
    }
    self.printTreeInner(left(idx), indents + 1);
    self.printTreeInner(right(idx), indents + 1);
}
