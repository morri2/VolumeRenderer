min: u32 = 0,
max: u32 = 0,
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

pub fn splitHalf(self: Self) .{ Self, Self } {
    return .{
        Self.new(self.min, (self.max + self.min) / 2),
        Self.new((self.max + self.min) / 2, self.max),
    };
}

pub fn splitAt(self: Self, d: u32) .{ Self, Self } {
    return .{
        Self.new(self.min, @max(self.max, self.min + d)),
        Self.new(@max(self.max, self.min + d), self.max),
    };
}
