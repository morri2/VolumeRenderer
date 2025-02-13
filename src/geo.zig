const SPACESIZE = @import("typedef.zig").SPACESIZE;
const ISOVAL = @import("typedef.zig").ISOVAL;

pub const VecF: type = Vec3(f32);
const std = @import("std");
pub const Axis = enum(u2) {
    const Self = @This();
    X,
    Y,
    Z,

    pub fn baseVector(self: Self, comptime T: type) Vec3(T) {
        switch (self) {
            .X => return Vec3(T).new(1, 0, 0),
            .Y => return Vec3(T).new(0, 1, 0),
            .Z => return Vec3(T).new(0, 0, 1),
        }
    }

    pub fn idx(self: Self) usize {
        return @intFromEnum(self);
    }

    pub fn next(self: Self) Self {
        switch (self) {
            .X => return .Y,
            .Y => return .Z,
            .Z => return .X,
        }
    }
};

pub const Ray = struct {
    origin: Vec3(f32),
    dir: Vec3(f32),

    pub fn point(self: @This(), t: f32) Vec3(f32) {
        return self.origin.add(self.dir.scale(t));
    }
};

pub const Cell = struct {
    arr: [3]SPACESIZE,
    pub fn x(self: @This()) SPACESIZE {
        return self.arr[0];
    }
    pub fn y(self: @This()) SPACESIZE {
        return self.arr[1];
    }
    pub fn z(self: @This()) SPACESIZE {
        return self.arr[2];
    }
};

pub fn Vec3(comptime T: type) type {
    return packed struct {
        const Self = @This();
        x: T,
        y: T,
        z: T,

        pub fn new(x: T, y: T, z: T) Self {
            return .{ .x = x, .y = y, .z = z };
        }

        pub fn single(v: T) Self {
            return .{ .x = v, .y = v, .z = v };
        }

        pub fn zero() Self {
            return single(0.0);
        }

        pub fn cell(self: Self) ?Cell {
            if (self.x < 0 or self.y < 0 or self.z < 0) return null;
            switch (@typeInfo(T)) {
                .Float => return .{ .arr = .{
                    @intFromFloat(self.x),
                    @intFromFloat(self.y),
                    @intFromFloat(self.z),
                } },
                .Int => return .{ .arr = .{
                    @intCast(self.x),
                    @intCast(self.y),
                    @intCast(self.z),
                } },
                else => unreachable,
            }
        }

        pub fn scale(self: Self, s: T) Self {
            return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
        }

        pub fn dot(self: Self, other: Self) T {
            return self.x * other.x + self.y * other.y + self.z * other.z;
        }

        pub fn len(self: Self) T {
            return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        }

        pub fn cross(self: Self, other: Self) Self {
            return .{
                .x = self.y * other.z - self.z * other.y,
                .y = self.z * other.x - self.x * other.z,
                .z = self.x * other.y - self.y * other.x,
            };
        }

        pub fn norm(self: Self) Self {
            switch (@typeInfo(T)) {
                .Float => return self.scale(1.0 / self.len()),
                else => {
                    std.debug.print("DONT NORMALIZE NON FLOATS", .{});
                    return self;
                },
            }
        }

        pub fn gtz(self: Self) Self {
            switch (@typeInfo(T)) {
                .Float => return Self.new(
                    @floatFromInt(@intFromBool(self.x >= 0.0)),
                    @floatFromInt(@intFromBool(self.y >= 0.0)),
                    @floatFromInt(@intFromBool(self.z >= 0.0)),
                ),
                .Int => return Self.new(
                    @intFromBool(self.x >= 0.0),
                    @intFromBool(self.y >= 0.0),
                    @intFromBool(self.z >= 0.0),
                ),
                else => unreachable,
            }
        }

        pub fn print(self: Self) void {
            std.debug.print("<{d},{d},{d}>", .{ self.x, self.y, self.z });
        }
    };
}

pub fn Range(comptime T: type) type {
    return packed struct {
        const Self = @This();
        min: T = 0,
        max: T = 0,

        pub fn new(min_incl: T, max_excl: T) Self {
            return .{ .min = min_incl, .max = max_excl };
        }

        pub fn new_single(val: T) Self {
            return new(val, val + 1);
        }

        pub fn contains(self: Self, val: T) bool {
            return self.min <= val and val < self.max;
        }

        pub fn containsFloat(self: Self, val: f32) bool {
            //std.debug.print("{d:}<={d:}<{d:}", .{ @as(f32, @floatFromInt(self.min)), val, @as(f32, @floatFromInt(self.max)) });
            return @as(f32, @floatFromInt(self.min)) <= val and val < @as(f32, @floatFromInt(self.max));
        }

        pub fn splitHalf(self: Self) .{ Self, Self } {
            return .{
                Self.new(self.min, (self.max + self.min) / 2),
                Self.new((self.max + self.min) / 2, self.max),
            };
        }

        pub fn splitAt(self: Self, d: T) .{ Self, Self } {
            return .{
                Self.new(self.min, @max(self.max, self.min + d)),
                Self.new(@max(self.max, self.min + d), self.max),
            };
        }

        pub fn len(self: Self) T {
            return self.max - self.min;
        }

        pub fn containsInclusive(self: Self, val: T) bool {
            return self.min <= val and val <= self.max;
        }
    };
}

pub fn Volume(comptime T: type) type {
    return packed struct {
        const Self = @This();
        xrange: Range(T),
        yrange: Range(T),
        zrange: Range(T),

        pub fn new(xr: [2]T, yr: [2]T, zr: [2]T) Self {
            return .{
                .xrange = Range(T).new(xr[0], xr[1]),
                .yrange = Range(T).new(yr[0], yr[1]),
                .zrange = Range(T).new(zr[0], zr[1]),
            };
        }

        pub fn contains(self: Self, coord: Cell) bool {
            return self.xrange.contains(coord.x()) and self.yrange.contains(coord.y()) and self.zrange.contains(coord.z());
        }

        pub fn containsFloat(
            self: Self,
            fcoord: Vec3(f32),
        ) bool {
            return self.xrange.containsFloat(fcoord.x) and self.yrange.containsFloat(fcoord.y) and self.zrange.containsFloat(fcoord.z);
        }

        pub fn splitMiddle(self: Self, normal_axis: Axis) [2]Self {
            return self.splitInternal(
                normal_axis,
                self.getAxisRange(normal_axis).len() / 2,
            );
        }

        pub fn splitInternal(self: Self, normal_axis: Axis, internal_offset: T) [2]Self {
            var a = self;
            var b = self;

            switch (normal_axis) {
                .X => {
                    a.xrange.max = @min(a.xrange.max, a.xrange.min + internal_offset);
                    b.xrange.min = @max(b.xrange.min, a.xrange.min + internal_offset);
                },
                .Y => {
                    a.yrange.max = @min(a.yrange.max, a.yrange.min + internal_offset);
                    b.yrange.min = @max(b.yrange.min, a.yrange.min + internal_offset);
                },
                .Z => {
                    a.zrange.max = @min(a.zrange.max, a.zrange.min + internal_offset);
                    b.zrange.min = @max(b.zrange.min, a.zrange.min + internal_offset);
                },
            }
            return .{ a, b };
        }

        pub fn splitGlobal(self: Self, normal_axis: Axis, split: T) [2]Self {
            var a = self;
            var b = self;

            switch (normal_axis) {
                .X => {
                    a.xrange.max = @min(a.xrange.max, split);
                    b.xrange.min = @max(b.xrange.min, split);
                },
                .Y => {
                    a.yrange.max = @min(a.yrange.max, split);
                    b.yrange.min = @max(b.yrange.min, split);
                },
                .Z => {
                    a.zrange.max = @min(a.zrange.max, split);
                    b.zrange.min = @max(b.zrange.min, split);
                },
            }
            return .{ a, b };
        }

        pub fn getAxisRange(self: Self, axis: Axis) Range(T) {
            switch (axis) {
                .X => return self.xrange,
                .Y => return self.yrange,
                .Z => return self.zrange,
            }
            return self.xrange;
        }

        pub fn setAxisRange(self: Self, range: Range(T), axis: Axis) void {
            switch (axis) {
                .X => self.xrange = range,
                .Y => self.yrange = range,
                .Z => self.zrange = range,
            }
        }

        pub fn axisSize(self: Self, normal_axis: Axis, internal_offset: T) [2]Self {
            var a = self;
            var b = self;

            switch (normal_axis) {
                .X => {
                    a.xrange.max = @min(a.xrange.max, a.xrange.min + internal_offset);
                    b.xrange.min = @max(b.xrange.min, a.xrange.min + internal_offset);
                },
                .Y => {
                    a.yrange.max = @min(a.yrange.max, a.yrange.min + internal_offset);
                    b.yrange.min = @max(b.yrange.min, a.yrange.min + internal_offset);
                },
                .Z => {
                    a.zrange.max = @min(a.zrange.max, a.zrange.min + internal_offset);
                    b.zrange.min = @max(b.zrange.min, a.zrange.min + internal_offset);
                },
            }
            return .{ a, b };
        }

        pub fn size(self: Self) u32 {
            return @as(u32, @intCast(self.xrange.len())) * @as(u32, @intCast(self.yrange.len())) * @as(u32, @intCast(self.zrange.len()));
        }

        pub fn largestDim(self: Self) Axis {
            if (self.xrange.len() > self.yrange.len() and self.xrange.len() > self.zrange.len()) {
                return .X;
            }
            if (self.yrange.len() > self.zrange.len()) {
                return .Y;
            }
            return .Z;
        }

        pub fn minVec(self: Self) Vec3(T) {
            return Vec3(T).new(self.xrange.min, self.yrange.min, self.zrange.min);
        }

        pub const VolumeIterator = struct {
            volume: Self,
            next_cell: ?Cell,

            pub fn next(self: *@This()) ?Cell {
                if (@typeInfo(T) != .Int) unreachable; // iterators not supported for non int space
                if (self.next_cell) |cell| {
                    self.next_cell.?.arr[0] += 1;
                    if (!self.volume.contains(self.next_cell.?)) {
                        self.next_cell.?.arr[0] = self.volume.xrange.min;
                        self.next_cell.?.arr[1] += 1;
                        if (!self.volume.contains(self.next_cell.?)) {
                            self.next_cell.?.arr[1] = self.volume.yrange.min;
                            self.next_cell.?.arr[2] += 1;
                            if (!self.volume.contains(self.next_cell.?)) {
                                self.next_cell = null;
                            }
                        }
                    }

                    return cell;
                } else {
                    return null;
                }
            }
        };

        pub fn initIterator(self: Self) VolumeIterator {
            return .{ .volume = self, .next_cell = .{
                .arr = .{ self.xrange.min, self.yrange.min, self.zrange.min },
            } };
        }

        pub fn planes(self: Self) [6]Plane(T) {
            return .{
                .{ .normal_axis = .X, .offset = self.xrange.min },
                .{ .normal_axis = .X, .offset = self.xrange.max },
                .{ .normal_axis = .Y, .offset = self.yrange.min },
                .{ .normal_axis = .Y, .offset = self.yrange.max },
                .{ .normal_axis = .Z, .offset = self.zrange.min },
                .{ .normal_axis = .Z, .offset = self.zrange.max },
            };
        }

        pub fn planesF(self: Self) [6]Plane(T) {
            switch (@typeInfo(T)) {
                .Float => return .{
                    .{ .normal_axis = .X, .offset = self.xrange.min },
                    .{ .normal_axis = .X, .offset = self.xrange.max },
                    .{ .normal_axis = .Y, .offset = self.yrange.min },
                    .{ .normal_axis = .Y, .offset = self.yrange.max },
                    .{ .normal_axis = .Z, .offset = self.zrange.min },
                    .{ .normal_axis = .Z, .offset = self.zrange.max },
                },
                .Int => return .{
                    .{ .normal_axis = .X, .offset = @floatFromInt(self.xrange.min) },
                    .{ .normal_axis = .X, .offset = @floatFromInt(self.xrange.max) },
                    .{ .normal_axis = .Y, .offset = @floatFromInt(self.yrange.min) },
                    .{ .normal_axis = .Y, .offset = @floatFromInt(self.yrange.max) },
                    .{ .normal_axis = .Z, .offset = @floatFromInt(self.zrange.min) },
                    .{ .normal_axis = .Z, .offset = @floatFromInt(self.zrange.max) },
                },
            }
        }
    };
}

pub fn Plane(comptime T: type) type {
    return struct {
        const Self = @This();
        normal_axis: Axis,
        offset: T,

        pub fn rayIntersect(self: Self, ray: Ray) f32 {
            const normal: Vec3(f32) = self.normal_axis.baseVector(f32);
            const center: Vec3(f32) = normal.scale(@floatFromInt(self.offset));
            //std.debug.print("normal: ", .{});
            //normal.print();

            //std.debug.print("  center: ", .{});
            //center.print();
            const denom: f32 = normal.dot(ray.dir);
            //std.debug.print("\n  denom: {d}", .{denom});

            if (@abs(denom) < 1e-8) return std.math.inf(f32);

            const t: f32 = ((center.sub(ray.origin)).dot(normal)) / denom;
            //std.debug.print("\n  t?: {d}  \n", .{t});

            //const t: f32 = -(normal.scale(offset).sub(ray.origin).dot(normal)) / denom;
            if (t > 0.0) return t;

            return -1;
        }

        pub fn firstIntersect(self: Self, ray: Ray, prev_t: f32) f32 {
            const normal: Vec3(f32) = self.normal_axis.baseVector(f32);
            const denom: f32 = normal.dot(ray.dir);
            if (denom > 0.0) {
                var offset: f32 = 0;

                switch (@typeInfo(T)) {
                    .Float => offset = @floatCast(self.offset),
                    .Int => offset = @floatFromInt(self.offset),
                    else => unreachable,
                }

                const t: f32 = -(normal.scale(offset).sub(ray.origin).dot(normal)) / denom;
                if (t > 0.0) return @min(t, prev_t);
            }
            return prev_t;
        }
    };
}
