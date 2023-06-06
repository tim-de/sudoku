# Sudoku

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

The response used here is to expose the heapify function in
the public api, as for this application, item priority is
updated in a batched fashion, so it makes sense to run a
single series of passes to update the whole heap rather than
having to find each of the items first.

## Sudoku Solving

### Depth First Search

The algorithm used here to solve sudoku puzzles is a form of
depth first search backtracking algorithm. The algorithm works
by sequentially choosing cells and assigning possible numbers.
If at any point there is a cell with no possible numbers the
last cell that was set is updated to the next possible value.
This is repeated recursively until all values have been filled in.

The application of the dway heap data structure is as a priority
queue used to determine the order to fill in cells. To minimise
the number of states that must be tested the cell with the fewest
options is selected.
