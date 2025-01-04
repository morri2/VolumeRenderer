const std = @import("std");

resulution: [3]u32 = .{ 0, 0, 0 },
allocator: std.heap.GeneralPurposeAllocator(.{}),
data: []u8,

/// function for format from ucd https://web.cs.ucdavis.edu/~okreylos/PhDStudies/Spring2000/ECS277/DataSets.html
pub fn loadUCD() !@This() {
    var file = try std.fs.cwd().openFile("C60.vol", .{});
    defer file.close();

    var reader = file.reader();

    const xdim = reader.readInt(u32, .big) catch unreachable;
    const ydim = reader.readInt(u32, .big) catch unreachable;
    const zdim = reader.readInt(u32, .big) catch unreachable;

    // unused
    _ = reader.readInt(u32, .big) catch unreachable;

    // true size
    _ = reader.readInt(u32, .big) catch unreachable;
    _ = reader.readInt(u32, .big) catch unreachable;
    _ = reader.readInt(u32, .big) catch unreachable;

    var new = init(xdim, ydim, zdim) catch unreachable;
    for (0..xdim) |x| {
        for (0..ydim) |y| {
            for (0..zdim) |z| {
                new.set(reader.readByte() catch unreachable, @intCast(x), @intCast(y), @intCast(z));
            }
        }
    }
    return new;
}

/// function for format from ucd https://web.cs.ucdavis.edu/~okreylos/PhDStudies/Spring2000/ECS277/DataSets.html
pub fn loadUCDcapped(maxdim: u32) !@This() {
    var file = try std.fs.cwd().openFile("C60.vol", .{});
    defer file.close();

    var reader = file.reader();

    const xdim = reader.readInt(u32, .big) catch unreachable;
    const ydim = reader.readInt(u32, .big) catch unreachable;
    const zdim = reader.readInt(u32, .big) catch unreachable;

    // unused
    _ = reader.readInt(u32, .big) catch unreachable;

    // true size
    _ = reader.readInt(u32, .big) catch unreachable;
    _ = reader.readInt(u32, .big) catch unreachable;
    _ = reader.readInt(u32, .big) catch unreachable;

    var out = init(@min(maxdim, xdim), @min(maxdim, ydim), @min(maxdim, zdim)) catch unreachable;
    for (0..xdim) |x| {
        for (0..ydim) |y| {
            for (0..zdim) |z| {
                const v = reader.readByte() catch unreachable;
                if (x >= maxdim or y >= maxdim or z >= maxdim) continue;
                out.set(v, @intCast(x), @intCast(y), @intCast(z));
            }
        }
    }
    return out;
}

pub fn init(xdim: u32, ydim: u32, zdim: u32) !@This() {
    std.debug.print("init data: {}x{}x{}\n", .{ xdim, ydim, zdim });
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    const data: []u8 = try allocator.alloc(u8, xdim * ydim * zdim);
    return .{ .resulution = .{ xdim, ydim, zdim }, .data = data, .allocator = gpa };
}

pub fn deinit(self: @This()) void {
    self.allocator.free(self.data);
}

pub fn get(self: @This(), x: u32, y: u32, z: u32) u8 {
    return self.data[x * (self.resulution[2] * self.resulution[1]) + y * (self.resulution[2]) + z];
}

pub fn set(self: @This(), d: u8, x: u32, y: u32, z: u32) void {
    self.data[x * (self.resulution[2] * self.resulution[1]) + y * (self.resulution[2]) + z] = d;
}
