var min: u32 = 0;
var max: u32 = 0;
const Self = @This();
pub fn new(min_incl: u32, max_excl: u32) Self {
    return .{ .min = min_incl, .max = max_excl };
}

pub fn new_single(val: u32) Self {
    return new(val, val + 1);
}

pub fn contains(self: Self, val: u32) bool {
    return self.min <= val and val < self.max;
}
