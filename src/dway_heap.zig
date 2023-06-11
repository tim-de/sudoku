const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

/// An implementation of a d-way heap storing type T,
/// and using S.compare to check which of two elements should
/// be higher in the heap, returning true if the first
/// argument should be higher, and false if the second should
/// be higher.
pub fn DwayHeap(comptime T: type, comptime S: struct {
    branch_factor: usize = 2,
    compare: fn (child: T, parent: T) bool,
}) type {
    // Ensure that the branching factor is at least 2
    const branch_factor: usize = if (S.branch_factor < 2) 2 else S.branch_factor;
    return struct {
        count: usize,
        store: []T,
        allocator: ?Allocator,

        /// Initialise a d-way heap backed by an existing array slice.
        /// Will alter the contents of the slice.
        pub fn init(store: []T) !DwayHeap(T, S) {
            var heap = DwayHeap(T, S){
                .count = store.len,
                .store = store,
                .allocator = null,
            };
            try heap.heapify();
            return heap;
        }

        /// Initialise an empty d-way heap backed by a heap-allocated array.
        /// Must be freed with DwayHeap.destroy() when no longer needed.
        pub fn create(capacity: usize, allocator: Allocator) !DwayHeap(T, S) {
            var store = try allocator.alloc(T, capacity);
            return DwayHeap(T, S){
                .count = 0,
                .store = store,
                .allocator = allocator,
            };
        }

        /// Copies the contents of an existing slice into the array slice
        /// backing the heap. Source slice must not be longer than the
        /// heap's store slice.
        pub fn load_data(self: *DwayHeap(T, S), src: []const T) !void {
            if (src.len > self.store.len) {
                if (self.allocator == null) {
                    return error.InsufficientCapacity;
                }
                self.store = try self.allocator.?.realloc(self.store, src.len);
            }
            for (src) |value, ix| self.store[ix] = value;
            self.count = src.len;
            try self.heapify();
        }

        /// Frees the underlying array slice backing a heap-allocated DwayHeap.
        /// Does nothing if created with init (lacking an allocator).
        pub fn destroy(self: *DwayHeap(T, S)) void {
            if (self.allocator != null) {
                self.allocator.?.free(self.store);
            }
        }

        /// Inserts an element into the heap
        pub fn add_elem(self: *DwayHeap(T, S), new_elem: T) !void {
            if (self.store.len <= self.count + 1) {
                if (self.allocator == null) {
                    return error.InsufficientCapacity;
                }
                self.store = try self.allocator.?.realloc(self.store, self.store.len + 1 + (self.store.len >> 1));
            }
            self.count += 1;
            self.store[self.count - 1] = new_elem;
            try self.float_up(self.count - 1);
        }

        /// Remove the top value from the heap and
        /// return it, ensuring the remaining elements
        /// of the heap are correctly ordered.
        pub fn pop(self: *DwayHeap(T, S)) !T {
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

        /// Return the top value from the heap without
        /// removing it.
        pub fn peek(self: *DwayHeap(T, S)) !T {
            if (self.count == 0) {
                return error.PopFromEmpty;
            }
            return self.store[0];
        }

        /// Add an element to the heap and then pop the
        /// top value from the heap. Performs this as a
        /// single step and is more efficient than
        /// separate calls to .add_elem() and .pop()
        pub fn push_pop(self: *DwayHeap(T, S), item: T) !T {
            if (self.count == 0) {
                return item;
            } else if (S.compare(item, self.store[0])) {
                return item;
            } else {
                const ret = self.store[0];
                self.store[0] = item;
                try self.sink_down(0);
                return ret;
            }
        }

        /// Pop the top element from the heap and then push a
        /// new item on to the heap, more efficiently than using
        /// two separate functions.
        pub fn replace(self: *DwayHeap(T, S), item: T) !T {
            if (self.count == 0) {
                return error.PopFromEmpty;
            }
            const ret = self.store[0];
            self.store[0] = item;
            try self.sink_down(0);
            return ret;
        }

        fn increase_key(self: *DwayHeap(T, S)) !void {
            for (self.store) |_, ix| {
                if (try self.float_up(ix) == true) {
                    return;
                }
            }
        }

        fn get_parent(self: *DwayHeap(T, S), ix: usize) !usize {
            _ = self;
            return (ix - 1) / branch_factor;
        }

        fn get_child(self: *DwayHeap(T, S), ix: usize, n_child: usize) !usize {
            _ = self;
            if (n_child >= branch_factor) {
                return error.InvalidChildNumber;
            }
            return (ix * branch_factor) + n_child + 1;
        }

        /// Returns the index in the heap of the child of root_ix with the
        /// highest priority
        fn get_max_child_ix(self: *DwayHeap(T, S), root_ix: usize) usize {
            const first_child_ix = (root_ix * branch_factor) + 1;
            const last_child_ix = if ((root_ix + 1) * branch_factor < self.count)
                (root_ix + 1) * branch_factor
            else
                self.count - 1;

            const children = self.store[first_child_ix .. last_child_ix + 1];
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
        fn is_childless(self: *DwayHeap(T, S), ix: usize) bool {
            return (ix * branch_factor) + 1 >= self.count;
        }

        /// Sorts the heap, ensuring that the heap property is satisfied.
        pub fn heapify(self: *DwayHeap(T, S)) !void {
            var ix = self.count / branch_factor;
            while (ix > 0) {
                ix -= 1;
                try self.sink_down(ix);
            }
        }

        /// Checks if the element at index ix is smaller than its parent,
        /// swapping them if so
        fn float_up(self: *DwayHeap(T, S), ix: usize) !void {
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
        fn sink_down(self: *DwayHeap(T, S), root_ix: usize) !void {
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
    var heap = try DwayHeap(dtype, .{ .compare = base_comp }).init(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop());
    try testing.expectEqual(@as(dtype, 12), try heap.pop());
    try testing.expectEqual(@as(dtype, 13), try heap.pop());
    try testing.expectEqual(@as(dtype, 18), try heap.pop());
    try testing.expectEqual(@as(dtype, 19), try heap.pop());
    try testing.expectEqual(@as(usize, 0), heap.count);
}

test "Sorting in a heap-allocated array slice" {
    const allocator = std.testing.allocator;
    const dtype: type = i32;
    const data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try DwayHeap(dtype, .{ .compare = base_comp }).create(16, allocator);
    defer heap.destroy();
    try heap.load_data(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop());
    try testing.expectEqual(@as(dtype, 12), try heap.pop());
    try testing.expectEqual(@as(dtype, 13), try heap.pop());
    try testing.expectEqual(@as(dtype, 18), try heap.pop());
    try testing.expectEqual(@as(dtype, 19), try heap.pop());
    try testing.expectEqual(@as(usize, 0), heap.count);
}

test "3-way heap in an existing array slice" {
    const dtype: type = f32;
    var data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try DwayHeap(dtype, .{
        .branch_factor = 3,
        .compare = base_comp,
    }).init(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop());
    try testing.expectEqual(@as(dtype, 12), try heap.pop());
    try testing.expectEqual(@as(dtype, 13), try heap.pop());
    try testing.expectEqual(@as(dtype, 18), try heap.pop());
    try testing.expectEqual(@as(dtype, 19), try heap.pop());
    try testing.expectEqual(@as(usize, 0), heap.count);
}

test "3-way heap in a heap-allocated array slice" {
    const allocator = std.testing.allocator;
    const dtype: type = i32;
    const data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try DwayHeap(dtype, .{ .branch_factor = 3, .compare = base_comp }).create(16, allocator);
    defer heap.destroy();
    try heap.load_data(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop());
    try testing.expectEqual(@as(dtype, 12), try heap.pop());
    try testing.expectEqual(@as(dtype, 13), try heap.pop());
    try testing.expectEqual(@as(dtype, 18), try heap.pop());
    try testing.expectEqual(@as(dtype, 19), try heap.pop());
    try testing.expectEqual(@as(usize, 0), heap.count);
}

test "load_data() allocating more memory after creation of heap." {
    const allocator = std.testing.allocator;
    const dtype: type = i32;
    const data = [_]dtype{ 12, 6, 18, 19, 13 };
    var heap = try DwayHeap(dtype, .{ .branch_factor = 3, .compare = base_comp }).create(3, allocator);
    defer heap.destroy();
    try heap.load_data(&data);
    try testing.expectEqual(@as(usize, 5), heap.count);
    try testing.expectEqual(@as(dtype, 6), try heap.pop());
    try testing.expectEqual(@as(dtype, 12), try heap.pop());
    try testing.expectEqual(@as(dtype, 13), try heap.pop());
    try testing.expectEqual(@as(dtype, 18), try heap.pop());
    try testing.expectEqual(@as(dtype, 19), try heap.pop());
    try testing.expectEqual(@as(usize, 0), heap.count);
}

test "add_elem() memory allocation test" {
    const dtype: type = i32;
    const allocator = std.testing.allocator;
    const data = [_]dtype{ 12, 6, 18, 20, 13 };
    var heap = try DwayHeap(dtype, .{ .branch_factor = 3, .compare = base_comp }).create(5, allocator);
    defer heap.destroy();

    try heap.load_data(&data);

    try testing.expectEqual(@as(usize, 5), heap.count);

    try heap.add_elem(45);

    try testing.expectEqual(@as(usize, 6), heap.count);

    try testing.expectEqual(@as(dtype, 6), try heap.pop());
    try testing.expectEqual(@as(dtype, 12), try heap.pop());
    try testing.expectEqual(@as(dtype, 13), try heap.pop());
    try testing.expectEqual(@as(dtype, 18), try heap.pop());
    try testing.expectEqual(@as(dtype, 20), try heap.pop());
    try testing.expectEqual(@as(dtype, 45), try heap.pop());

    try testing.expectEqual(@as(usize, 0), heap.count);
}
