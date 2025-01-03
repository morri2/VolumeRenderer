const std = @import("std");
const Range = @import("Range.zig");
const Space = @import("Space.zig");
const Cell = Space.Cell;
const Data = @import("Data.zig");

const Self = @This();
const MAX_INNER_NODES: comptime_int = 1000;
pub const ROOT = 0;

nodes: [MAX_INNER_NODES]Node = undefined,

const Node = struct {
    leaf: bool,
    space: Space,
    dens_range: Range,
};

pub fn zoom(self: Self, idx: u32, cell: Cell) ?u32 {
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
fn left(i: u32) u32 {
    return 2 * i + 1;
}

fn right(i: u32) u32 {
    return 2 * i + 2;
}

fn parent(i: u32) u32 {
    return (i - 1) / 2;
}

// pub fn binaryPartionFromData(data: Data) void {
//     _ = data; // autofix
//     var tree: Self = .{};

//     _ = tree; // autofix

// }

// pub fn binaryPartionFromDataInner(self: *Self, data: Data, idx: u32, space: Space) void {
//     const is_leaf = space.size() == 1;
//     self.nodes[idx] = .{ .leaf = is_leaf, .space = Space.new(.{ 0, 3 }, .{ 0, 3 }, .{ 0, 3 }), .dens_range = Range.new(0, 0) };
//     if (self.nodes[idx].leaf) {
//         return;
//     }

//     self.newTestTreeInner(left(idx), level + 1);
//     self.newTestTreeInner(right(idx), level + 1);
// }

// ///////////////// //
// STUFF FOR TESTING //
// ///////////////// //

pub fn newTestTree() Self {
    var tree: Self = .{};
    tree.newTestTreeInner(ROOT, 0);
    return tree;
}

pub fn newTestTreeInner(self: *Self, idx: u32, level: u32) void {
    const is_leaf = level >= 3;
    self.nodes[idx] = .{ .leaf = is_leaf, .space = Space.new(.{ 0, 3 }, .{ 0, 3 }, .{ 0, 3 }), .dens_range = Range.new(0, 0) };
    if (self.nodes[idx].leaf) {
        return;
    }
    self.newTestTreeInner(left(idx), level + 1);
    self.newTestTreeInner(right(idx), level + 1);
}

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
