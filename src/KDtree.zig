const std = @import("std");
const Range = @import("Range");
const Self = @This();
const MAX_INNER_NODES: comptime_int = 1000;
const ROOT = 0;

inner_nodes: [MAX_INNER_NODES]Node = undefined,

const Node = struct {
    leaf: bool,
    //dens_range: Range,
};

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
    self.inner_nodes[idx] = .{ .leaf = is_leaf };
    if (self.inner_nodes[idx].leaf) {
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
    if (self.inner_nodes[idx].leaf) {
        return;
    }
    self.printTreeInner(left(idx), indents + 1);
    self.printTreeInner(right(idx), indents + 1);
}
