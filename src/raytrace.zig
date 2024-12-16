const KDtree = @import("KDtree.zig");
const Space = @import("Space.zig");
const Point = Space.Point;
const Coord = Space.Coord;

pub const Ray = struct {
    origin: Point,
    dir: Point,
};

// pub fn traceRay(ray: Ray, tree: KDtree) void {
//     var t: f32 = 0.0;
//     var pos: Point = ray.dir.scale(t).add(ray.origin);
// }
//
// pub fn rayAAPlaneIntersect(ray: Ray, plane: Plane) void {}
