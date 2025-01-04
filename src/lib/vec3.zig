const std = @import("std");

pub fn Vec3(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        const T_ZERO: T = 0;
        const T_ONE: T = 1;

        // Constructors
        pub fn new(x: T, y: T, z: T) Self {
            return .{ .x = x, .y = y, .z = z };
        }

        pub fn newSingle(v: T) Self {
            return new(v, v, v);
        }

        pub fn zero() Self {
            return newSingle(T_ZERO);
        }

        // Casting
        pub fn asCoord(self: Self) void {
            return .{ .x = @intFromFloat(self.x), .y = @intFromFloat(self.y), .z = @intFromFloat(self.z) };
        }

        // Manipulations
        pub fn scale(self: Self, s: T) Self {
            return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
        }

        pub fn addSingle(self: Self, c: T) Self {
            return .{ .x = self.x + c, .y = self.y + c, .z = self.z + c };
        }

        pub fn mul(self: Self, other: Self) Self {
            return .{ .x = self.x * other.x, .y = self.y * other.y, .z = self.z * other.z };
        }

        // greater than zero (element wise)
        pub fn gtz(self: Self) Self {
            return new(@floatFromInt(@intFromBool(self.x >= T_ZERO)), //
                @floatFromInt(@intFromBool(self.y >= T_ZERO)), //
                @floatFromInt(@intFromBool(self.z >= T_ZERO)));
        }

        // OBS! will be sad if unsigned
        pub fn sign(self: Self) Self {
            return self.gtz().scale(2.0).addSingle(-1.0);
        }

        pub fn dot(self: Self, other: Self) T {
            return self.x * other.x + self.y * other.y + self.z * other.z;
        }

        // PRINT
        pub fn print(self: Self) void {
            std.debug.print("({d} {d} {d})", .{ self.x, self.y, self.z });
        }
    };
}
