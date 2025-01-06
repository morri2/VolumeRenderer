const std = @import("std");
const geo = @import("geo.zig");
const ISOVAL = @import("typedef.zig").ISOVAL;
resulution: [3]u32 = .{ 0, 0, 0 },
allocator: std.heap.GeneralPurposeAllocator(.{}),
data: []u8,

/// function for format from ucd https://web.cs.ucdavis.edu/~okreylos/PhDStudies/Spring2000/ECS277/DataSets.html
pub fn loadUCD(file_name: []const u8) !@This() {
    var file = try std.fs.cwd().openFile(file_name, .{});
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
pub fn loadUCDcapped(file_name: []const u8, maxdim: u32) !@This() {
    var file = try std.fs.cwd().openFile(file_name, .{});
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

pub fn set(self: *@This(), d: u8, x: u32, y: u32, z: u32) void {
    self.data[x * (self.resulution[2] * self.resulution[1]) + y * (self.resulution[2]) + z] = d;
}

pub fn size(self: *const @This()) usize {
    return self.resulution[0] * self.resulution[1] * self.resulution[2];
}

pub fn getCornerDens(self: *const @This(), cell: geo.Cell) [8]ISOVAL {
    return .{ self.get(cell.x(), cell.y(), cell.z()), self.get(cell.x() + 1, cell.y(), cell.z()), self.get(cell.x(), cell.y() + 1, cell.z()), self.get(cell.x(), cell.y(), cell.z() + 1), self.get(cell.x() + 1, cell.y() + 1, cell.z()), self.get(cell.x(), cell.y() + 1, cell.z() + 1), self.get(cell.x() + 1, cell.y(), cell.z() + 1), self.get(cell.x() + 1, cell.y() + 1, cell.z() + 1) };
}

pub fn getCornerDensRange(self: *const @This(), cell: geo.Cell) geo.Range(ISOVAL) {
    var min_d: ISOVAL = std.math.maxInt(ISOVAL);
    var max_d: ISOVAL = 0;
    for (self.getCornerDens(cell)) |v| {
        min_d = @min(min_d, v);
        max_d = @max(max_d, v);
    }
    return geo.Range(ISOVAL).new(min_d, max_d);
}
