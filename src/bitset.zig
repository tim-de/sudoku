const std = @import("std");
const testing = std.testing;

const BitSet = struct {
    value: u32 = 0,

    pub fn init(value: u32) void {
        return BitSet{ .value = value };
    }

    pub fn setBit(self: *BitSet, offset: u32) void {
        self.value |= 1 << (offset & 31);
    }

    pub fn clearBit(self: *BitSet, offset: u32) void {
        self.value &= ~(1 << (offset & 31));
    }

    pub fn clearAll(self: *BitSet) void {
        self.value = 0;
    }
};

test "Initialise a BitSet with a value" {
    const testSet = BitSet.init(12);
    try testing.expectEqual(@as(u32, 12), testSet.value);
}
