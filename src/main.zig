const std = @import("std");
const minHeap = @import("binheap.zig").minHeap;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

fn u32_to_i32(num: u32) i32 {
    return @bitCast(i32, num -% (1 << 31));
}

pub fn main() !void {
    var data = [_]u32{ 12, 6, 18, 19, 13 };
    var heap = try minHeap(u32, u32_to_i32).init(data[0..data.len]);
    std.debug.print("Heap contains {d} elements\n", .{heap.count});
    while (heap.count > 0) {
        std.debug.print("{d}\n", .{try heap.pop_root()});
    }
}
