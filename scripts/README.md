# Packing Repo

Contains scripts for generating MLIR from C code, for optimizing .mlir files, and to lower them to executables.
More instructions, including how to build necessary tools in each folder.

## Main Scripts

1. Use the **polygeist** script to translate the kernels from Polybench to .mlir files
2. Use **polymer** to optimize the .mlir files with pluto (tiling, interchange, etc.)
    - Alternatively, use **affine-tiling** to tile the inputs using the tiling pass in affine
3. Use **mlir-packing** to apply packing to the outputs of polymer
4. Use **lower-to-binary** to create the binaries from any of the .mlir files generated
5. Use **polly** to create binaries of the polybench benchmarks compiled with LLVM's Polly

## Experiments

The **experiments** folder contains scripts and files that allow to evaluate packing.

There are two experiments used to generate the results presented in the paper:
1. **polybench-evaluation**
2. **packing-selection-evaluation**

The folder **google-benchmark** is an auxiliary set of scripts for **packing-selection-evaluation**.
But it can also be used on its own.

More details can be found inside each experiment folder.

### Experimental Setup

Edit the file `experiments/spec.file` with the parameters of the machine in which the experiments will be run.

## Docker

The **docker** folder contains the Dockerfile that generates the docker image available in artifact of the paper.
