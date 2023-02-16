# Sudoku

This is going to contain a sudoku solver. For the time being,
however, it's just data structure implementation!

## Dway Heap
An implementation of the dway heap data structure, which
functions as a more generalised form of binary heap where
each node can have at most d children rather than just 2.

The implementation performs all necessary tasks for use as
a priority queue, but the in/decrease key functions are not
implemented. These functions require the heap indices to be
exposed to the user of the data structure, which is hard to
manage reliably. For example, if the user calls increase key
on an element, then it may change position within the heap,
displacing other elements, whose positions cannot be easily
tracked, even if the new index of the target element is
returned from the function.

I can think of several possible solutions to this, each with
advantages and disadvantages:

1. Return a list of old-new index pairs from the function

	**Pros:**
	- Enables the user to keep track of all changing indices.
	
	**Cons:**
	- Requires the user maintaining some additional data structure
   to hold the indices of the items, somewhat defeating the point
   of having a heap.
   - Significantly complicates the operation and return of the
   functions responsible for exchanging values in the heap

2. Do not expose the indices, but expose `heapify()`, requiring the
user to call it every time one or more elements is changed to
ensure that the heap property is conserved.

	**Pros:**
	- Indices are encapsulated within the heap data structure,
	and the user does not need to separately keep track of the
	position of their data within the structure.
		
	**Cons:**
	- The entire heap must be updated every time any value changes.

3. Implement a heap element container type that holds the value and
its current index, allowing the user to find it as needed

	**Pros:**
	- Manages keeping track of the indices so they are available
	to the user.
	
	**Cons:**
	- Significantly limits the way the type can be used, as the
	user must convert their data into the correct format prior to
	insertion into the data structure. Alternatively, the structure
	must be heap-allocated and the container type added when data
	is inserted into the structure.
	- However it is implemented, it significantly complicates the
	implementation of the structure.

### To-do list
- [x] Replace minHeap's evaluation function with a comparison
used to evaluate priority
	- [x] maybe then rename it as it won't be
   strictly a min heap
- [x] Refactor minHeap to use a struct as an argument instead
of several different parameters, which are a bit messy.
- [ ] Work out how to handle indices into the heap, if they are
exposed to the user (if so how) or not (and how to handle
increase-key &c. in this case)
- [x] Add the capacity to supply a branch factor for the heap
at compile time, implementing a more general d-ary/dway heap.
	- [x] Replace the relative index function so that more than
	two children can be indexed if the heap supports it.
- [ ] Implement reallocation to automatically adjust store size
if capacity is reached and store is heap-allocated.
