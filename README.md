# Sudoku

This is going to contain a sudoku solver. For the time being,
however, it's just data structure implementation!

## Binary Heap
This is still in a fairly early stage, and it kind of works,
but there are significant changes I would like to make.

### To-do list
- [x] Replace minHeap's evaluation function with a comparison
used to evaluate priority
	- [ ] maybe then rename it as it won't be
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
