const Range = @import("Range.zig");
const Plane = @import("Plane.zig");
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

    pub fn cell(self: @This()) Cell {
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

    pub fn dot(self: Self, other: Self) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn len(self: Self) Self {
        return @sqrt(self.x + self.y + self.z);
    }

    pub fn cross(self: Self, other: Self) Self {
        return .{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn norm(self: Self) Self {
        return self.scale(1.0 / self.len());
    }

    pub fn gtz(self: Self) Self {
        return Self.new(
            @floatFromInt(@intFromBool(self.x >= 0.0)),
            @floatFromInt(@intFromBool(self.y >= 0.0)),
            @floatFromInt(@intFromBool(self.z >= 0.0)),
        );
    }
};

pub fn planes(self: Self) [6]Plane {
    return .{
        .{ .normal_axis = .X, .offset = @floatFromInt(self.xrange.min) }, //
        .{ .normal_axis = .X, .offset = @floatFromInt(self.xrange.max) }, //
        .{ .normal_axis = .Y, .offset = @floatFromInt(self.yrange.min) }, //
        .{ .normal_axis = .Y, .offset = @floatFromInt(self.yrange.max) }, //
        .{ .normal_axis = .Z, .offset = @floatFromInt(self.zrange.min) }, //
        .{ .normal_axis = .Z, .offset = @floatFromInt(self.zrange.max) }, //
    };
}

pub const Cell = packed struct { x: u16, y: u16, z: u16 };

xrange: Range,
yrange: Range,
zrange: Range,

const Self = @This();
pub fn new(xr: [2]u32, yr: [2]u32, zr: [2]u32) Self {
    return .{
        .xrange = Range.new(xr[0], xr[1]),
        .yrange = Range.new(yr[0], yr[1]),
        .zrange = Range.new(zr[0], zr[1]),
    };
}

// pub fn containsF(self: Self, val: u32) bool {
//     return self.xrange.contains(val) and self.yrange.contains(val) and self.zrange.contains(val);
// }

pub fn contains(self: Self, coord: Cell) bool {
    return self.xrange.contains(coord.x) and self.yrange.contains(coord.y) and self.zrange.contains(coord.z);
}

pub fn size(self: Self) u32 {
    return self.xrange.len() * self.yrange.len() * self.zrange.len();
}
