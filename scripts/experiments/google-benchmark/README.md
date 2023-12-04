# Google Benchmark

Google benchmark version used: **v1.6.1**    

Enables benchmarking kernels with Google Benchmark.

To see how to run:

```sh
./compile-benchmark.sh -h
```

### Modes

There are three execution modes:
- CLANG
- POLLY
- MLIR

For CLANG and POLLY, use as input the c files provided in this folder.
For MLIR, use any mlir file.

### Benchmarks

There are two benchmarks supported:
- 2mm
- gemm