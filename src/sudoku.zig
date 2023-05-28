const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const DwayHeap = @import("dway_heap.zig").DwayHeap;
const BitSet = std.bit_set.IntegerBitSet(9);
const CellHeap = DwayHeap(*SudokuCell, .{
    .branch_factor = 3,
    .compare = cellCompare,
});

const SudokuCell = struct {
    value: u8 = 0,
    options: BitSet = BitSet.initEmpty(),
    neighbours: [20]?*SudokuCell = undefined,

    fn init(value: u8) SudokuCell {
        return SudokuCell{ .value = value };
    }
};

fn cellCompare(a: anytype, b: @TypeOf(a)) bool {
    return b.options.count() < a.options.count();
}

const SudokuGrid = struct {
    grid: *[9][9]SudokuCell,
    heap: CellHeap,

    fn fromArray(arr: []const u8, allocator: Allocator) !SudokuGrid {
        var ret: SudokuGrid = SudokuGrid{
            .grid = try allocator.create([9][9]SudokuCell),
            .heap = try CellHeap.create(81, allocator),
        };
        for (arr) |value, ix| {
            const j = ix / 9;
            const i = ix % 9;
            ret.grid[j][i].value = value;
        }
        return ret;
    }

    fn cleanUp(self: *SudokuGrid, allocator: Allocator) void {
        allocator.destroy(self.grid);
        self.heap.destroy();
    }
};

test "Initialise a SudokuGrid from an array" {
    const arr = [_]u8{ 8, 9, 1 };
    var grid = try SudokuGrid.fromArray(&arr, std.testing.allocator);
    defer {
        grid.cleanUp(std.testing.allocator);
    }
    try testing.expectEqual(grid.grid[0][0].value, @as(u8, 8));
}
