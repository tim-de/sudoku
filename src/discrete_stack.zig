const std = @import("std");

const testing = std.testing;

/// A stack implementation of comptime defined capacity
/// that can therefore be instantiated on the stack
/// as a function-local variable
fn DiscreteStack(comptime T: type, comptime C: usize) type {
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

        /// Pop the top value from the stack
        pub fn pop(self: *DiscreteStack(T, C)) !T {
            if (self.index <= 0) {
                return error.popFromEmpty;
            }
            self.index -= 1;
            const ret = self.store[self.index];
            return ret;
        }
    };
}

test "Initialise empty stack and fail to read" {
    var stack = DiscreteStack(i32, 20){};
    try testing.expectError(error.popFromEmpty, stack.pop());
}

test "Push items to stack and retrieve them" {
    var stack = DiscreteStack(i32, 3){};
    try stack.push(12);
    try stack.push(8);
    try stack.push(9);
    try testing.expectError(error.outOfSpace, stack.push(69));
    try testing.expectEqual(@as(i32, 9), try stack.pop());
    try testing.expectEqual(@as(i32, 8), try stack.pop());
    try testing.expectEqual(@as(i32, 12), try stack.pop());
    try testing.expectError(error.popFromEmpty, stack.pop());
}
