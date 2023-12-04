# Lower to Binary

Clang version used: **14.0.1**

Use `lower-to-binary-plus.sh` to compiler polybench kernels in MLIR to binaries.

To see how to run:

```sh
./lower-to-binary-plus.sh -h
```

## Limitations
This lowering matches the .c and .mlir calling interface with [bare pointers](https://mlir.llvm.org/docs/TargetLLVMIR/#bare-pointer-calling-convention-for-ranked-memref).
This convention further restricts the supported cases to the following.
- memref types with default layout.
- memref types with all dimensions statically known.
- memref values allocated in such a way that the allocated and aligned pointer match. Alternatively, the same function must handle allocation and deallocation since only one pointer is passed to any callee.


