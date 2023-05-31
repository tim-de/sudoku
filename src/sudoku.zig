const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const DiscreteStack = @import("discrete_stack.zig").DiscreteStack;
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
    options: BitSet,
    neighbours: [20]*SudokuCell = undefined,

    fn init(value: usize) SudokuCell {
        return SudokuCell{ .value = value };
    }

    fn setOptions(self: *SudokuCell) void {
        self.options.setUnion(BitSet.initFull());
        self.options.unset(0);
        if (self.value != 0) {
            self.options.setIntersection(BitSet.initEmpty());
            return;
        }
        for (self.neighbours) |neighbour| {
            if (neighbour.value != 0) {
                self.options.unset(neighbour.value);
            }
        }
    }
};

const SolveState = struct {
    cell: *SudokuCell,
    iterator: BitSet.Iterator(.{}) = undefined,
    changed: DiscreteStack(*SudokuCell, 20),
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
            break :box Coordinate{ .i = (3 * box_i) + i_offset, .j = (3 * box_j) + j_offset };
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

        for (ret.grid) |*row, j| {
            for (row) |*cell, i| {
                cell.setOptions();
                if (cell.options.count() > 0) {
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
                if ((i + 1) % 3 == 0) {
                    try stdout.print(" ", .{});
                }
            }
            if ((j + 1) % 3 == 0) {
                try stdout.print("\n", .{});
            }
            try stdout.print("\n", .{});
        }
        try stdout.print(" --------------------\n", .{});
    }

    fn assignNeighbours(self: *SudokuGrid) void {
        for (self.grid) |row, j| {
            for (row) |_, i| {
                var n: usize = 0;
                while (n < 20) {
                    const neighbour_pos = getNeighbourPosition(Coordinate{ .i = i, .j = j }, n);
                    self.grid[j][i].neighbours[n] = &self.grid[neighbour_pos.j][neighbour_pos.i];
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
            var changed_cells = [_]?*SudokuCell{null} ** 20;
            var changed_cell_ix: usize = 0;
            cell.value = option;
            if (self.heap.count == 0) {
                return true;
            }
            for (cell.neighbours) |neighbour| {
                if (neighbour.value == 0 and neighbour.options.isSet(option)) {
                    changed_cells[changed_cell_ix] = neighbour;
                    changed_cell_ix += 1;
                    neighbour.options.unset(option);
                }
            }
            try self.heap.heapify();
            //try self.draw();
            if (try self.depthFirstSearch(allocator)) {
                return true;
            }
            cell.value = 0;
            //cell.setOptions();
            changed_cell_ix = 0;
            while (changed_cells[changed_cell_ix]) |changed_cell| {
                changed_cell.options.set(option);
                //changed_cell.setOptions();
                changed_cell_ix += 1;
            }
            try self.heap.heapify();
        }
        try self.heap.add_elem(cell);
        return false;
    }

    pub fn depthFirstSearchNoRecurse(self: *SudokuGrid) void {
        var state_stack = DiscreteStack(SolveState, 81){};
        var state = SolveState{ .cell = try self.heap.pop(), .iterator = .cell.options.iterator(.{}) };

        while (true) {
            const option_try = state.iterator.next();
            if (option_try) |option| {
                state.cell.value = option;
                if (self.heap.count <= 0) {
                    return;
                }
                for (state.cell.neighbours) |neighbour| {
                    if (neighbour.value == 0 and neighbour.options.isSet(option)) {
                        try state.changed.push(neighbour);
                        neighbour.options.unset(option);
                    }
                }
                try self.heap.heapify();
                try state_stack.push(state);
                state = SolveState{ .cell = try self.heap.pop(), .iterator = .cell.options.iterator(.{}) };
                state.changed.index = 0;
            } else {
                state.cell.value = 0;
                self.heap.push(state.cell);
                state = try state_stack.pop();
            }
        }
    }
};

test "Get neighbour positions" {
    const testpos = Coordinate{ .i = 3, .j = 5 };
    // Test getting a value from the same row
    try testing.expectEqual(Coordinate{ .i = 2, .j = 5 }, getNeighbourPosition(testpos, 2));
    // Test getting a value from the same column
    try testing.expectEqual(Coordinate{ .i = 3, .j = 2 }, getNeighbourPosition(testpos, 10));
    // Test getting a value from the same box
    try testing.expectEqual(Coordinate{ .i = 4, .j = 3 }, getNeighbourPosition(testpos, 16));
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

    try testing.expect(!grid.grid[0][0].options.isSet(5));
    for (grid.grid) |row| {
        for (row) |cell| {
            for (cell.neighbours) |neighbour| {
                if (neighbour == undefined) {
                    unreachable;
                }
            }
        }
    }
}
