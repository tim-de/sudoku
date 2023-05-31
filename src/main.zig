const std = @import("std");
const SudokuGrid = @import("sudoku.zig").SudokuGrid;
var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
const allocator = gpa.allocator();

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const arr = [_]u8{ 0, 0, 5, 0, 4, 0, 0, 0, 7, 0, 7, 0, 0, 0, 6, 0, 0, 0, 0, 9, 3, 0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 9, 0, 0, 0, 8, 0, 0, 0, 6, 0, 8, 0, 0, 0, 1, 0, 0, 0, 7, 0, 0, 0, 3, 0, 0, 4, 0, 0, 0, 9, 3, 0, 0, 0, 0, 8, 0, 0, 0, 6, 0, 7, 0, 0, 0, 1, 0, 5, 0, 0 };
    // Try and solve a grid
    var grid = try SudokuGrid.fromArray(&arr, allocator);
    defer grid.cleanUp(allocator);
    try grid.draw();
    if (try grid.depthFirstSearch(allocator)) {
        try stdout.print("Success!\n", .{});
        try grid.draw();
    } else {
        try stdout.print("Failure :(\n", .{});
    }
}
