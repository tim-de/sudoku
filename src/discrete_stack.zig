const std = @import("std");

const testing = std.testing;

/// A stack implementation of comptime defined capacity
/// that can therefore be instantiated on the stack
/// as a function-local variable.
pub fn DiscreteStack(comptime T: type, comptime C: usize) type {
    return struct {
        store: [C]T = undefined,
        index: usize = 0,

        /// Push a value to the stack
        pub fn push(self: *DiscreteStack(T, C), item: T) !void {
            if (self.index >= self.store.len) {
                return error.outOfSpace;
            }
            self.store[self.index] = item;
            self.index += 1;
        }

        /// Pop the top value from the stack, returning null
        /// in the case of an empty stack
        pub fn pop(self: *DiscreteStack(T, C)) ?T {
            if (self.index <= 0) {
                return null;
            }
            self.index -= 1;
            return self.store[self.index];
        }
    };
}

test "Initialise empty stack and read null" {
    var stack = DiscreteStack(i32, 20){};
    try testing.expect(if (stack.pop()) |_| false else true);
}

test "Push items to stack and retrieve them" {
    var stack = DiscreteStack(i32, 3){};
    try stack.push(12);
    try stack.push(8);
    try stack.push(9);
    try testing.expectError(error.outOfSpace, stack.push(69));
    try testing.expectEqual(@as(i32, 9), stack.pop().?);
    try testing.expectEqual(@as(i32, 8), stack.pop().?);
    try testing.expectEqual(@as(i32, 12), stack.pop().?);
    try testing.expect(if (stack.pop()) |_| false else true);
}
