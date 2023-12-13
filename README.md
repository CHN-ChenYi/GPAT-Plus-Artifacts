# Artifacts for GPAT-Plus

This project is based on `C. Salvador Rohwedder et al. "To pack or not to pack: A generalized packing analysis and transformation" in Proceedings of the 21st ACM/IEEE International Symposium on Code Generation and Optimization, 2023, pp. 14–27`([10.1145/3579990.3580024](https://dl.acm.org/doi/10.1145/3579990.3580024)).

## How to use it

### Setup

Build a docker image using `./scripts/docker/Dockerfile` or directly import the docker image from [10.5281/zenodo.7517506](https://doi.org/10.5281/zenodo.7517506).

### Run

Almost the same as the original artifacts.

## Source code branches

The source code is in the `src/` folder, linked to the [GPAT-Plus](https://github.com/CHN-ChenYi/GPAT-Plus) repository. There are several branches of it:

* `main`: GPAT
* `if_analysis`: Accounting for Mutual Exclusive Branches in Cache Residency Analysis
  * `baseline_if_analysis`: GPAT with some additional logging logics
* `permutation`: More Fine-grained Permutation
* `multithread_test`: Explore Multi-thread Impact. The running scripts are in `./src/scripts`
