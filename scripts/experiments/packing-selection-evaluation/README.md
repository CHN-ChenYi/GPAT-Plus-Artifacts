# Packing Selection Evaluation

This experiment applies tiling (and other loop optimizations) to a benchmark using **Polymer** with a range of tiling factors.
The same tiling factor is applied to all loops of the benchmark.
This is the baseline of this experiment.

To each different tiling that composes the baseline, packing is applied in two ways.

First, the packing applied by **GPAT**.

Second, individually, packing is applied to all packing candidates that present reuse (that pass Phase 1 of GPAT).
For example, in the *gemm* benchmark, at tiling factor 32, if there are 2 candidates *x* and *y* after Phase 1, packing is applied individually to *x* creating *gemm-32-x* and packing is also applied individually to *y* creating *gemm-32-y*.
And this is done for each tiling factor.
In the graphs, the performance of these packings are shown as **Individual Packings**.

## Benchmarks Avalaible

- *2mm* optimized by Polymer
- *gemm* optimized by Polymer
- *gemm* optimized by Polymer and interchanged to BLIS loop ordering

As a base for these benchmarks, the .mlir files in the `inputs` folder are used.
These .mlir files were generated using Polygeist without any manual changes.

## How to use

1. Generate files
   1. Tiles benchmark mlir kernel through a range of tiling factors
   2. Applies the two types of packing mentioned above to the benchmark
   3. Compiles and generates binaries of all versions of the benchmark

To see how to run:

```sh
./generate-files.sh -h
```

2. Run binaries
   1. Google Benchmark records execution time statistics
   2. Perf optionally records hardware event counters
   3. Generates an output log with all data

Pass as input the folder with executables generated in the above step.
To see how to run:

```sh
./run.sh -h
```

3. Parse log
   1. Summarizes statistics
   2. Generates csv with data
   3. Generates graphs

Pass as input the output log generated in the above step.
To see how to run:

```sh
./parse-log.py -h
```

## Usage example

```sh
OUTPUT_DIR="output-gemm-LARGE"

mkdir ${OUTPUT_DIR}
mkdir ${OUTPUT_DIR}/graphs

./generate-files.sh -D LARGE -B gemm ${OUTPUT_DIR}
./run.sh -D LARGE ${OUTPUT_DIR}/executables ${OUTPUT_DIR}
./parse-log.py ${OUTPUT_DIR}/output.log ${OUTPUT_DIR}/graphs gemm
```

```sh
OUTPUT_DIR="output-gemm-BLIS-LARGE"

mkdir ${OUTPUT_DIR}
mkdir ${OUTPUT_DIR}/graphs

./generate-files.sh -D LARGE -B gemm-blis ${OUTPUT_DIR}
./run.sh -D LARGE ${OUTPUT_DIR}/executables ${OUTPUT_DIR}
./parse-log.py ${OUTPUT_DIR}/output.log ${OUTPUT_DIR}/graphs gemm-blis
```

```sh
OUTPUT_DIR="output-2mm-LARGE"

mkdir ${OUTPUT_DIR}
mkdir ${OUTPUT_DIR}/graphs

./generate-files.sh -D LARGE -B 2mm ${OUTPUT_DIR}
./run.sh -D LARGE ${OUTPUT_DIR}/executables ${OUTPUT_DIR}
./parse-log.py ${OUTPUT_DIR}/output.log ${OUTPUT_DIR}/graphs 2mm
```
