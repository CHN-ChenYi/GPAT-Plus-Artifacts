# Benchmark Polybench

The baseline in this experiment is each benchmark compiled with **Clang -O3**, more specifically, with the following flags:
```
-O3 -ffast-math -march=native -emit-llvm -S -flto
```

This experiment can use two different tiling engines:
- **Polymer** applies tiling (and other loop optimizations) to a benchmark using a range of tiling factors. The same tiling factor is applied to all loops of the benchmark.
- **Affine Tiling** applies tiling to a benchmark using the tiling pass from MLIR Affine. It takes a cache parameter as input, namely, the size of L1, L2, and L3.

To each different tiling, packing is applied **GPAT**.

Each benchmark is also compiled with LLVM's **Polly**.

All benchmarks in Polybench are used. Additionally, the running example of the paper *contraction-3D* was also incorporated into Polybench.
But, only the benchmarks in which packing was applied are run.

## How to use

1. Generate files
   1. Translates Polybench kernels with Polygeist to MLIR Affine
   2. Tiles Polybench mlir kernels with Polymer or Affine Tiling
   3. Applies packing with GPAT to the tiled kernels
   4. Removes kernels that were not packed by GPAT so they are not run
   6. Compiles and generates binaries of all remaining kernels

To see how to run:

```sh
./generate-files.sh -h
```

2. Run binaries
   1. Polybench records execution time
   2. Perf optionally records hardware event counters
   3. Generates an output dir with with all log data

Pass as input the folder with executables generated in the above step.
To see how to run:

```sh
./run.sh -h
```

3. Parse log
   1. Summarizes statistics
   2. Generates csv with data
   3. Generates graphs

Pass as input the output dir with log data generated in the above step.
To see how to run:

```sh
./parser-log.py -h
```

## Usage examples

```sh
OUTPUT_DIR="output-polybench-affine-LARGE"

mkdir ${OUTPUT_DIR}
mkdir ${OUTPUT_DIR}/logs
mkdir ${OUTPUT_DIR}/graphs

./generate-files.sh -D LARGE -T AffineTiling ${OUTPUT_DIR}
./run.sh -D LARGE ${OUTPUT_DIR} ${OUTPUT_DIR}/logs
./parse-log.py ${OUTPUT_DIR}/logs ${OUTPUT_DIR}/graphs AffineTiling
```

```sh
OUTPUT_DIR="output-polybench-polymer-LARGE"

mkdir ${OUTPUT_DIR}
mkdir ${OUTPUT_DIR}/logs
mkdir ${OUTPUT_DIR}/graphs

./generate-files.sh -D LARGE -T Polymer ${OUTPUT_DIR}
./run.sh -D LARGE ${OUTPUT_DIR} ${OUTPUT_DIR}/logs
./parse-log.py ${OUTPUT_DIR}/logs ${OUTPUT_DIR}/graphs Polymer
```
