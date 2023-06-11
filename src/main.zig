const std = @import("std");
const sudoku = @import("sudoku.zig");
const SudokuGrid = sudoku.SudokuGrid;
const SudokuCell = sudoku.SudokuCell;
var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
const allocator = gpa.allocator();

pub fn main() !void {
    //const stdout = std.io.getStdOut().writer();
    //const arr = [_]u8{ 0, 0, 5, 0, 4, 0, 0, 0, 7, 0, 7, 0, 0, 0, 6, 0, 0, 0, 0, 9, 3, 0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 9, 0, 0, 0, 8, 0, 0, 0, 6, 0, 8, 0, 0, 0, 1, 0, 0, 0, 7, 0, 0, 0, 3, 0, 0, 4, 0, 0, 0, 9, 3, 0, 0, 0, 0, 8, 0, 0, 0, 6, 0, 7, 0, 0, 0, 1, 0, 5, 0, 0 };
    //const arr = [_]u8{ 0, 7, 0, 8, 2, 0, 5, 0, 0, 5, 0, 8, 9, 0, 0, 2, 0, 4, 4, 0, 0, 7, 1, 5, 0, 0, 6, 0, 0, 5, 0, 0, 8, 0, 1, 0, 1, 8, 6, 0, 5, 0, 9, 4, 3, 0, 2, 0, 6, 0, 0, 7, 0, 0, 8, 0, 0, 5, 3, 6, 0, 0, 9, 9, 0, 3, 0, 0, 2, 4, 0, 7, 0, 0, 1, 0, 7, 9, 0, 6, 0 };
    //const arr = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 0, 8, 5, 0, 0, 1, 0, 2, 0, 0, 0, 0, 0, 0, 0, 5, 0, 7, 0, 0, 0, 0, 0, 4, 0, 0, 0, 1, 0, 0, 0, 9, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 7, 3, 0, 0, 2, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 9 };
    // Try and solve a grid
    var gridBuf = [_]SudokuGrid{SudokuGrid{}} ** 50;
    var grids = try read_grids("p096_sudoku.txt", &gridBuf);
    var heap = try sudoku.CellHeap.create(81, allocator);
    for (grids) |*itergrid| {
        itergrid.heap = heap;
        itergrid.assignNeighbours();
        try itergrid.initHeap();
        try itergrid.draw();
        if (try itergrid.depthFirstSearch()) {
            std.debug.print("Success!", .{});
            try itergrid.draw();
        } else {
            std.debug.print("Failed!", .{});
        }
    }
}

fn read_grids(filename: []const u8, buf: []SudokuGrid) ![]SudokuGrid {
    var pathbuf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const filepath = try std.fs.realpath(filename, &pathbuf);
    var file = try std.fs.openFileAbsolute(filepath, .{});
    defer file.close();
    var buf_reader = std.io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var filebuf: [1024]u8 = undefined;
    var outbuf_ix: usize = 0;
    var grid_ix: usize = 0;
    var first_grid: bool = true;
    while (try in_stream.readUntilDelimiterOrEof(&filebuf, '\n')) |line| {
        if (line[0] >= 0x30 and line[0] <= 0x39) {
            for (line) |char| {
                if (char < 0x30 or char > 0x39) {
                    return error.ValueError;
                }
                buf[outbuf_ix].grid[grid_ix / 9][grid_ix % 9].value = (char - 0x30);
                grid_ix += 1;
            }
            if (first_grid) {
                first_grid = false;
            }
        } else {
            if (!first_grid) {
                outbuf_ix += 1;
            }
            if (outbuf_ix >= buf.len) {
                return error.outOfRange;
            }
            grid_ix = 0;
        }
    }
    return buf[0 .. outbuf_ix + 1];
}
