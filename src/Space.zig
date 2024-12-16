const Range = @import("Range.zig");

pub const Point = packed struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn new(x: f32, y: f32, z: f32) @This() {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn single(v: f32) @This() {
        return .{ .x = v, .y = v, .z = v };
    }

    pub fn zero() @This() {
        return single(0.0);
    }

    pub fn asCoord(self: @This()) void {
        return .{ .x = @intFromFloat(self.x), .y = @intFromFloat(self.y), .z = @intFromFloat(self.z) };
    }

    pub fn scale(self: @This(), s: f32) @This() {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
    }

    pub fn add(self: @This(), other: @This()) @This() {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn mul(self: @This(), other: @This()) @This() {
        return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
    }
};
pub const Coord = packed struct { x: u16, y: u16, z: u16 };

xrange: Range,
yrange: Range,
zrange: Range,

const Self = @This();
pub fn new(xr: .{ u32, u32 }, yr: .{ u32, u32 }, zr: .{ u32, u32 }) Self {
    return .{
        .xrange = Range.new(xr[0], xr[1]),
        .yrange = Range.new(yr[0], yr[1]),
        .zrange = Range.new(zr[0], zr[1]),
    };
}

pub fn containsF(self: Self, val: u32) bool {
    return self.xrange.contains(val) and self.yrange.contains(val) and self.zrange.contains(val);
}

pub fn contains(self: Self, coord: Coord) bool {
    return self.xrange.contains(coord.x) and self.yrange.contains(coord.y) and self.zrange.contains(coord.z);
}
