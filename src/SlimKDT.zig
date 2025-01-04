
const Self = @This();
const geo = @import("geo.zig");

const SPACESIZE = @import("typedef.zig").SPACESIZE;
const ISOVAL = @import("typedef.zig").ISOVAL;

pub const SlimNode = packed struct {
    density_range: geo.Range(ISOVAL),
    partition: SPACESIZE,
};


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
pub fn zoom(self: Self, idx: u32, partition_axis: geo.Axis, cell: geo.Cell) struct { next_is_leaf: bool, next_idx: u32, next_space: geo.Volume(SPACESIZE) } {
    
    const next_idx = left(idx);
    if (self.nodes[left])
    if (self.nodes[left(idx)].space.contains(cell)) {
        next_idx = 
        return .{self.n left(idx)};
    } else {
        return right(idx);
    }
}
