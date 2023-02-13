const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

/// Number of children per node. To be replaced with an
/// integral part of a d-ary heap type later.
const branch_factor = 2;

/// An implementation of a binary heap storing type T and
/// capable of holding C elements. Must be provided with
/// an evaluation function that takes type T and returns
/// an i32 which will be used to determine the ordering
/// within the heap. Inverting the sign of the evaluations
/// will implement a max heap.
fn base_comp(A: anytype, B: @TypeOf(A)) bool {
    return A < B;
}

//pub fn minHeap(comptime T: type, comptime F: fn (T, T) bool) type {
pub fn minHeap(comptime S: struct {
    dtype: type = u32,
    compare: fn (anytype, anytype) bool = base_comp,
}) type {
    return struct {
        count: usize,
        store: []S.dtype,
        allocator: ?Allocator,

        /// Initialise a binary heap backed by an existing array slice.
        /// Will alter the contents of the slice.
        pub fn init(store: []S.dtype) !minHeap(S) {
            var heap = minHeap(S){
                .count = store.len,
                .store = store,
                .allocator = null,
            };
            try heap.heapify();
            return heap;
        }

        /// Initialise a binary heap backed by a heap-allocated array.
        /// Must be freed with minHeap.destroy() when no longer needed.
        pub fn create(capacity: usize, allocator: Allocator) !minHeap(S) {
            var store = try allocator.alloc(S.dtype, capacity);
            return minHeap(S){
                .count = 0,
                .store = store,
                .allocator = allocator,
            };
        }

        /// Copies the contents of an existing slice into the array slice
        /// backing the heap. Source slice must not be longer than the
        /// heap's store slice.
        pub fn load_data(self: *minHeap(S), src: *[]S.dtype) !void {
            if (src.len > self.store.len) {
                return error.InsufficientCapacity;
            }
            for (src) |value, ix| self.store[ix] = value;
            try self.heapify();
        }

        /// Frees the underlying array slice backing a heap-allocated minHeap.
        /// Does nothing if created with init (lacking an allocator).
        pub fn destroy(self: *minHeap(S)) void {
            if (self.allocator != null) {
                self.allocator.free(self.store);
            }
        }

        /// Inserts an element into the heap
        pub fn add_elem(self: *minHeap(S), new_elem: S.dtype) !void {
            self.count += 1;
            if (self.count >= self.store.len) {
                self.count -= 1;
                return error.InsufficientCapacity;
            }
            self.store[self.count - 1] = new_elem;
            try self.float_up(self.count - 1);
        }

        pub fn pop_root(self: *minHeap(S)) !S.dtype {
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

        pub fn increase_key(self: *minHeap(S)) !void {
            for (self.store) |_, ix| {
                if (try self.float_up(ix) == true) {
                    return;
                }
            }
        }

        fn get_parent(self: *minHeap(S), ix: usize) !usize {
            _ = self;
            return try (ix - 1) / branch_factor;
        }

        fn get_child(self: *minHeap(S), ix: usize, n_child: usize) !usize {
            _ = self;
            if (n_child >= branch_factor) {
                return error.InvalidChildNumber;
            }
            return (ix * branch_factor) + 1 + n_child;
        }

        /// Sorts the heap, ensuring that the heap property is satisfied.
        fn heapify(self: *minHeap(S)) !void {
            var ix = self.count / branch_factor;
            while (ix > 0) {
                ix -= 1;
                try self.sink_down(ix);
            }
        }

        /// Checks if the element at index ix is smaller than its parent,
        /// swapping them if so
        fn float_up(self: *minHeap(S), ix: usize) !void {
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

        /// Check if the element at index ix is larger than its children,
        /// swapping them if so.
        fn sink_down(self: *minHeap(S), root_ix: usize) !void {
            if (root_ix >= self.count) {
                return error.IndexOutOfRange;
            }
            const a_ix = try self.get_child(root_ix, 0);
            const b_ix = try self.get_child(root_ix, 1);

            if (a_ix >= self.count) {
                return;
            } else if (b_ix >= self.count) {
                if (S.compare(self.store[a_ix], self.store[root_ix])) {
                    const tmp = self.store[a_ix];
                    self.store[a_ix] = self.store[root_ix];
                    self.store[root_ix] = tmp;
                }
            } else if (S.compare(self.store[a_ix], self.store[b_ix])) {
                if (S.compare(self.store[a_ix], self.store[root_ix])) {
                    const tmp = self.store[a_ix];
                    self.store[a_ix] = self.store[root_ix];
                    self.store[root_ix] = tmp;
                    try self.sink_down(a_ix);
                }
            } else if (S.compare(self.store[b_ix], self.store[root_ix])) {
                const tmp = self.store[b_ix];
                self.store[b_ix] = self.store[root_ix];
                self.store[root_ix] = tmp;
                try self.sink_down(b_ix);
            }
        }
    };
}

fn u32_comp(a: u32, b: u32) bool {
    return a < b;
}

test "Sorting an existing array slice" {
    const dtype: type = f32;
    var data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try minHeap(.{ .dtype = dtype }).init(data[0..data.len]);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 12), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 13), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 18), try heap.pop_root());
    try testing.expectEqual(@as(dtype, 19), try heap.pop_root());
    try testing.expectEqual(@as(usize, 0), heap.count);
}
