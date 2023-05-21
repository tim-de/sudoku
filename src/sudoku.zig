const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

const dwayHeap = @import("dway_heap.zig").dwayHeap;
const BitSet = @import("bitset.zig").BitSet;

const SudokuCell = struct {
    value: u8,
    options: BitSet,
    neighbours: [20]*SudokuCell,
};
