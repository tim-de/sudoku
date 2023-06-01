const std = @import("std");
const sudoku = @import("sudoku.zig");
const SudokuGrid = sudoku.SudokuGrid;
const SudokuCell = sudoku.SudokuCell;
var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
const allocator = gpa.allocator();

pub fn main() !void {
    //const stdout = std.io.getStdOut().writer();
    //const arr = [_]u8{ 0, 0, 5, 0, 4, 0, 0, 0, 7, 0, 7, 0, 0, 0, 6, 0, 0, 0, 0, 9, 3, 0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 9, 0, 0, 0, 8, 0, 0, 0, 6, 0, 8, 0, 0, 0, 1, 0, 0, 0, 7, 0, 0, 0, 3, 0, 0, 4, 0, 0, 0, 9, 3, 0, 0, 0, 0, 8, 0, 0, 0, 6, 0, 7, 0, 0, 0, 1, 0, 5, 0, 0 };
    const arr = [_]u8{ 0, 7, 0, 8, 2, 0, 5, 0, 0, 5, 0, 8, 9, 0, 0, 2, 0, 4, 4, 0, 0, 7, 1, 5, 0, 0, 6, 0, 0, 5, 0, 0, 8, 0, 1, 0, 1, 8, 6, 0, 5, 0, 9, 4, 3, 0, 2, 0, 6, 0, 0, 7, 0, 0, 8, 0, 0, 5, 3, 6, 0, 0, 9, 9, 0, 3, 0, 0, 2, 4, 0, 7, 0, 0, 1, 0, 7, 9, 0, 6, 0 };
    // Try and solve a grid
    var grid = SudokuGrid{};
    var gridstore = [_][9]SudokuCell{[_]SudokuCell{SudokuCell{}} ** 9} ** 9;
    try grid.setup(&gridstore, &arr, allocator);
    defer grid.cleanUp(allocator);
    try grid.draw();
    if (!try grid.depthFirstSearch()) {
        std.debug.print("Failed!", .{});
    }
    //try grid.depthFirstSearchNoRecurse();
    try grid.draw();
}
