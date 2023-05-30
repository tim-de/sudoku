const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const DwayHeap = @import("dway_heap.zig").DwayHeap;
const BitSet = std.bit_set.IntegerBitSet(10);
const CellHeap = DwayHeap(*SudokuCell, .{
    .branch_factor = 3,
    .compare = cellCompare,
});

const Coordinate = struct {
    i: usize,
    j: usize,
};

const SudokuCell = struct {
    value: usize = 0,
    options: BitSet = BitSet.initFull(),
    neighbours: [20]*SudokuCell = undefined,

    fn init(value: usize) SudokuCell {
        return SudokuCell{ .value = value };
    }

    fn setOptions(self: *SudokuCell) void {
        self.options.unset(0);
        if (self.value != 0) {
            return;
        }
        for (self.neighbours) |neighbour| {
            if (neighbour.value != 0) {
                self.options.unset(neighbour.value);
            }
        }
    }
};

fn getNeighbourPosition(pos: Coordinate, n: usize) Coordinate {
    return switch (n) {
        0...7 => row: {
            var offset: usize = n;
            if (offset >= pos.i) {
                offset += 1;
            }
            break :row Coordinate{ .i = offset, .j = pos.j };
        },
        8...15 => column: {
            var offset: usize = n - 8;
            if (offset >= pos.j) {
                offset += 1;
            }
            break :column Coordinate{ .i = pos.i, .j = offset };
        },
        else => box: {
            const box_i = pos.i / 3;
            const box_j = pos.j / 3;
            const i_in_box = pos.i % 3;
            const j_in_box = pos.j % 3;
            var i_offset = (n - 16) / 2;
            var j_offset = (n - 16) % 2;
            // this should probably become
            // an inlined function
            if (i_in_box == 0) {
                i_offset += 1;
            } else if (i_in_box == 1) {
                i_offset *= 2;
            }
            if (j_in_box == 0) {
                j_offset += 1;
            } else if (j_in_box == 1) {
                j_offset *= 2;
            }
            break :box Coordinate{ .i = box_i + i_offset, .j = box_j + j_offset };
        },
    };
}

fn cellCompare(a: anytype, b: @TypeOf(a)) bool {
    return b.options.count() < a.options.count();
}

pub const SudokuGrid = struct {
    grid: *[9][9]SudokuCell,
    heap: CellHeap,

    pub fn fromArray(arr: []const u8, allocator: Allocator) !SudokuGrid {
        var ret: SudokuGrid = SudokuGrid{
            .grid = try allocator.create([9][9]SudokuCell),
            .heap = try CellHeap.create(81, allocator),
        };
        for (arr) |value, ix| {
            const j = ix / 9;
            const i = ix % 9;
            ret.grid[j][i].value = value;
        }
        ret.assignNeighbours();

        for (ret.grid) |row, j| {
            for (row) |_, i| {
                ret.grid[j][i].setOptions();
                if (ret.grid[j][i].options.count() > 0) {
                    try ret.heap.add_elem(&ret.grid[j][i]);
                }
            }
        }
        return ret;
    }

    pub fn cleanUp(self: *SudokuGrid, allocator: Allocator) void {
        allocator.destroy(self.grid);
        self.heap.destroy();
    }

    pub fn draw(self: SudokuGrid) !void {
        const stdout = std.io.getStdOut().writer();
        for (self.grid) |row, j| {
            for (row) |cell, i| {
                try stdout.print(" {d}", .{cell.value});
                if (i % 3 == 0) {
                    try stdout.print(" ", .{});
                }
            }
            if (j % 3 == 0) {
                try stdout.print("\n", .{});
            }
            try stdout.print("\n", .{});
        }
    }

    fn getNeighbour(self: *SudokuGrid, i: usize, j: usize, n: usize) *SudokuCell {
        return switch (n) {
            0...7 => row: {
                var offset: usize = n;
                if (offset >= i) {
                    offset += 1;
                }
                break :row &self.grid[j][offset];
            },
            8...15 => column: {
                var offset: usize = n - 8;
                if (offset >= j) {
                    offset += 1;
                }
                break :column &self.grid[offset][i];
            },
            else => box: {
                const box_i = i / 3;
                const box_j = j / 3;
                const i_in_box = i % 3;
                const j_in_box = j % 3;
                var i_offset = (n - 16) / 2;
                var j_offset = (n - 16) % 2;
                // this should probably become
                // an inlined function
                if (i_in_box == 0) {
                    i_offset += 1;
                } else if (i_in_box == 1) {
                    i_offset *= 2;
                }
                if (j_in_box == 0) {
                    j_offset += 1;
                } else if (j_in_box == 1) {
                    j_offset *= 2;
                }
                break :box &self.grid[box_j + j_offset][box_i + i_offset];
            },
        };
    }

    fn assignNeighbours(self: *SudokuGrid) void {
        for (self.grid) |row, j| {
            for (row) |_, i| {
                var n: usize = 0;
                while (n < 20) {
                    self.grid[j][i].neighbours[n] = self.getNeighbour(i, j, n);
                    n += 1;
                }
            }
        }
    }

    pub fn depthFirstSearch(self: *SudokuGrid, allocator: Allocator) !bool {
        var cell = try self.heap.pop();
        if (cell.options.count() == 0) {
            try self.heap.add_elem(cell);
            return false;
        }
        var iterator = cell.options.iterator(.{});
        while (iterator.next()) |option| {
            var changed_cells = try allocator.alloc(?*SudokuCell, 20);
            defer allocator.free(changed_cells);
            var changed_cell_ix: usize = 0;
            cell.value = option;
            if (self.heap.count == 0) {
                return true;
            }
            for (cell.neighbours) |neighbour| {
                if (neighbour.value == 0 and cell.options.isSet(neighbour.value)) {
                    changed_cells[changed_cell_ix] = neighbour;
                    changed_cell_ix += 1;
                    neighbour.options.unset(option);
                }
            }
            try self.heap.heapify();
            if (try self.depthFirstSearch(allocator)) {
                return true;
            }
            cell.value = 0;
            for (changed_cells) |optional_neighbour| {
                if (optional_neighbour) |neighbour| {
                    neighbour.options.set(option);
                }
            }
            try self.heap.heapify();
        }
        try self.heap.add_elem(cell);
        return false;
    }
};

test "Get neighbour positions" {
    const testpos = Coordinate{ .i = 3, .j = 5 };
    try testing.expectEqual(Coordinate{ .i = 2, .j = 5 }, getNeighbourPosition(testpos, 2));
    try testing.expectEqual(Coordinate{ .i = 3, .j = 2 }, getNeighbourPosition(testpos, 10));
}

test "Set values in a SudokuCell" {
    var test_cell = SudokuCell{ .value = 0 };
    test_cell.options.unset(6);
    try testing.expect(!test_cell.options.isSet(6));
}

test "Setup an actual sudoku puzzle" {
    const arr = [_]u8{ 0, 0, 5, 0, 4, 0, 0, 0, 7, 0, 7, 0, 0, 0, 6, 0, 0, 0, 0, 9, 3, 0, 0, 0, 1, 0, 0, 2, 0, 0, 0, 9, 0, 0, 0, 8, 0, 0, 0, 6, 0, 8, 0, 0, 0, 1, 0, 0, 0, 7, 0, 0, 0, 3, 0, 0, 4, 0, 0, 0, 9, 3, 0, 0, 0, 0, 8, 0, 0, 0, 6, 0, 7, 0, 0, 0, 1, 0, 5, 0, 0 };
    var grid = try SudokuGrid.fromArray(&arr, std.testing.allocator);
    defer grid.cleanUp(std.testing.allocator);
    try testing.expectEqual(grid.grid[0][0].value, @as(u8, 0));
    try testing.expectEqual(grid.grid[0][4].value, @as(u8, 4));
    try testing.expectEqual(grid.grid[2][1].value, @as(u8, 9));
}
