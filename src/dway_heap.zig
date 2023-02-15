const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

/// An implementation of a d-ary heap storing type S.dtype,
/// and using S.compare to check which of two elements should
/// be higher in the heap, returning true if the first
/// argument should be higher, and false if the second should
/// be higher.
pub fn dwayHeap(comptime S: struct {
    dtype: type = i32,
    branch_factor: usize = 2,
    compare: fn (anytype, anytype) bool = base_comp,
}) type {
    // Ensure that the branching factor is at least 2
    const branch_factor: usize = if (S.branch_factor < 2) 2 else S.branch_factor;
    return struct {
        count: usize,
        store: []S.dtype,
        allocator: ?Allocator,

        /// Initialise a dway heap backed by an existing array slice.
        /// Will alter the contents of the slice.
        pub fn init(store: []S.dtype) !dwayHeap(S) {
            var heap = dwayHeap(S){
                .count = store.len,
                .store = store,
                .allocator = null,
            };
            try heap.heapify();
            return heap;
        }

        /// Initialise an empty dway heap backed by a heap-allocated array.
        /// Must be freed with dwayHeap.destroy() when no longer needed.
        pub fn create(capacity: usize, allocator: Allocator) !dwayHeap(S) {
            var store = try allocator.alloc(S.dtype, capacity);
            return dwayHeap(S){
                .count = 0,
                .store = store,
                .allocator = allocator,
            };
        }

        /// Copies the contents of an existing slice into the array slice
        /// backing the heap. Source slice must not be longer than the
        /// heap's store slice.
        pub fn load_data(self: *dwayHeap(S), src: []const S.dtype) !void {
            if (src.len > self.store.len) {
                return error.InsufficientCapacity;
            }
            for (src) |value, ix| self.store[ix] = value;
            self.count = src.len;
            try self.heapify();
        }

        /// Frees the underlying array slice backing a heap-allocated dwayHeap.
        /// Does nothing if created with init (lacking an allocator).
        pub fn destroy(self: *dwayHeap(S)) void {
            if (self.allocator != null) {
                self.allocator.?.free(self.store);
            }
        }

        /// Inserts an element into the heap
        pub fn add_elem(self: *dwayHeap(S), new_elem: S.dtype) !void {
            if (self.store.len <= self.count + 1) {
                return error.InsufficientCapacity;
            }
            self.store[self.count] = new_elem;
            try self.float_up(self.count);
            self.count += 1;
        }

        pub fn pop_root(self: *dwayHeap(S)) !S.dtype {
            if (self.count == 0) {
                return error.PopFromEmpty;
            }
            const ret = self.store[0];
            self.count -= 1;
            if (self.count > 0) {
                self.store[0] = self.store[self.count];
                try self.sink_down(0);
            }
            return ret;
        }

        pub fn increase_key(self: *dwayHeap(S)) !void {
            for (self.store) |_, ix| {
                if (try self.float_up(ix) == true) {
                    return;
                }
            }
        }

        fn get_parent(self: *dwayHeap(S), ix: usize) !usize {
            _ = self;
            return try (ix - 1) / branch_factor;
        }

        fn get_child(self: *dwayHeap(S), ix: usize, n_child: usize) !usize {
            _ = self;
            if (n_child >= branch_factor) {
                return error.InvalidChildNumber;
            }
            return (ix * branch_factor) + 1 + n_child;
        }

        /// Returns the index in the heap of the child of root_ix with the
        /// highest priority
        fn get_max_child_ix(self: *dwayHeap(S), root_ix: usize) usize {
            const first_child_ix = (root_ix * branch_factor) + 1;
            const last_child_ix = if ((root_ix + 1) * branch_factor < self.count)
                (root_ix + 1) * branch_factor
            else
                self.count - 1;

            const children = self.store[first_child_ix..last_child_ix];
            var max_ix: usize = 0;
            for (children) |child, ix| {
                if (S.compare(child, children[max_ix])) {
                    max_ix = ix;
                }
            }
            return max_ix + first_child_ix;
        }

        /// Returns true if the node at ix has no children
        /// (index of children is outside the range used
        /// by the heap)
        fn is_childless(self: *dwayHeap(S), ix: usize) bool {
            return (ix * branch_factor) + 1 >= self.count;
        }

        /// Sorts the heap, ensuring that the heap property is satisfied.
        fn heapify(self: *dwayHeap(S)) !void {
            var ix = self.count / branch_factor;
            while (ix > 0) {
                ix -= 1;
                try self.sink_down(ix);
            }
        }

        /// Checks if the element at index ix is smaller than its parent,
        /// swapping them if so
        fn float_up(self: *dwayHeap(S), ix: usize) !void {
            if (ix >= self.count) {
                return error.IndexOutOfRange;
            }

            if (ix == 0) {
                return;
            }

            const parent_ix = try self.get_parent(ix);

            if (S.compare(self.store[parent_ix], self.store[ix])) {
                return;
            }

            const tmp = self.store[parent_ix];
            self.store[parent_ix] = self.store[ix];
            self.store[ix] = tmp;
            try self.float_up(parent_ix);
            return;
        }

        /// check if the element at index ix is larger than its children,
        /// swapping them if so.
        fn sink_down(self: *dwayHeap(S), root_ix: usize) !void {
            if (root_ix >= self.count) {
                return error.IndexOutOfRange;
            }

            if (self.is_childless(root_ix)) {
                return;
            }

            const max_child_index = self.get_max_child_ix(root_ix);

            if (S.compare(self.store[max_child_index], self.store[root_ix])) {
                const tmp = self.store[max_child_index];
                self.store[max_child_index] = self.store[root_ix];
                self.store[root_ix] = tmp;
                try self.sink_down(max_child_index);
            }
        }
    };
}

/// The default comparison function to use. Must be replaced for
/// any type that is not an integer or float, or to implement a
/// max heap.
fn base_comp(A: anytype, B: @TypeOf(A)) bool {
    return A < B;
}

test "Sorting in an existing array slice" {
    const dtype: type = f32;
    var data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try dwayHeap(.{ .dtype = dtype }).init(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 12), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 13), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 18), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 19), try heap.pop_root());
    try testing.expectEqual(@as(usize, 0), heap.count);
}

test "Sorting in a heap-allocated array slice" {
    const allocator = std.testing.allocator;
    const dtype: type = i32;
    const data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try dwayHeap(.{}).create(16, allocator);
    defer heap.destroy();
    try heap.load_data(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 12), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 13), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 18), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 19), try heap.pop_root());
    try testing.expectEqual(@as(usize, 0), heap.count);
}

test "3-way heap in an existing array slice" {
    const dtype: type = f32;
    var data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try dwayHeap(.{ .branch_factor = 3, .dtype = dtype }).init(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 12), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 13), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 18), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 19), try heap.pop_root());
    try testing.expectEqual(@as(usize, 0), heap.count);
}

test "3-way heap in a heap-allocated array slice" {
    const allocator = std.testing.allocator;
    const dtype: type = i32;
    const data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try dwayHeap(.{ .branch_factor = 3 }).create(16, allocator);
    defer heap.destroy();
    try heap.load_data(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 12), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 13), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 18), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 19), try heap.pop_root());
    try testing.expectEqual(@as(usize, 0), heap.count);
}
