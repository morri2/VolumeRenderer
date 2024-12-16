const KDtree = @import("KDtree.zig");
const Space = @import("Space.zig");
const Point = Space.Point;
const Coord = Space.Coord;

pub const Ray = struct {
    origin: Point,
    dir: Point,

    pub fn point(self: @This(), t: f32) Point {
        return self.origin.add(self.dir.scale(t));
    }
};
