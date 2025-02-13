const Ray = @import("raytrace.zig").Ray;
const Self = @This();
const Vec3 = @import("vec3.zig").Vec3(f32);

pub const Axis = enum {
    X,
    Y,
    Z,

    pub fn baseVector(self: Self) Vec3 {
        switch (self) {
            .X => return Vec3(1, 0, 0),
            .Y => return Vec3(0, 1, 0),
            .Z => return Vec3(0, 0, 1),
        }
    }
};

normal_axis: Axis,
offset: f32,

pub fn rayIntersect(self: Self, ray: Ray) f32 {
    const normal: Vec3 = self.normal_axis.baseVector();
    const denom: f32 = normal.dot(ray.dir);
    if (denom > 0.0) {
        const t: f32 = -(normal.scale(self.offset).sub(ray.origin).dot(normal)) / denom;
        if (t > 0.0) return t;
    }
    return -1;
}

pub fn Plane(comptime T: type) type {
    return struct {
        normal_axis: Axis,
        offset: T,

        pub fn rayIntersect(self: Self, ray: Ray) ?f32 {
            const normal: Vec3 = self.normal_axis.baseVector();
            const denom: f32 = normal.dot(ray.dir);
            if (denom > 0.0) {
                const t: f32 = -(normal.scale(self.offset).sub(ray.origin).dot(normal)) / denom;
                if (t > 0.0) return t;
            }
            return -1;
        }
    };
}
