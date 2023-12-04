#include <iostream>
#include <benchmark/benchmark.h>
#include "gemm.h"

/* Array initialization. */
void init_array(int ni, int nj, int nk,
                double *alpha,
                double *beta,
                double C[NI][NJ],
                double A[NI][NK],
                double B[NK][NJ]) {
  int i, j;

  *alpha = 1.5;
  *beta = 1.2;
  for (i = 0; i < ni; i++)
    for (j = 0; j < nj; j++)
      C[i][j] = (double) (i*j % ni) / ni;
  for (i = 0; i < ni; i++)
    for (j = 0; j < nk; j++)
      A[i][j] = (double) (i*(j+1) % nk) / nk;
  for (i = 0; i < nk; i++)
    for (j = 0; j < nj; j++)
      B[i][j] = (double) (i*(j+2) % nj) / nj;
}

extern "C" void kernel_gemm(int ni, int nj, int nk,
                            double alpha,
                            double beta,
                            double *C,
                            double *A,
                            double *B);

static void BM_GEMM(benchmark::State& state) {
  /* Retrieve problem size. */
  int ni = NI;
  int nj = NJ;
  int nk = NK;

  /* Variable declaration/allocation. */
  double alpha;
  double beta;
  double (*C)[NI][NJ];
  double (*A)[NI][NK];
  double (*B)[NK][NJ];

  C = (double(*)[NI][NJ]) aligned_alloc(1024, (NI) * (NJ) * sizeof(double));;
  A = (double(*)[NI][NK]) aligned_alloc(1024, (NI) * (NK) * sizeof(double));;
  B = (double(*)[NK][NJ]) aligned_alloc(1024, (NK) * (NJ) * sizeof(double));;

  /* Initialize array(s). */
  init_array (ni, nj, nk, &alpha, &beta,
          *(C),
          *(A),
          *(B));

  for (auto _ : state) {
    /* Run kernel. */
    kernel_gemm(ni, nj, nk,
                alpha, beta,
                (double*)&C[0][0],
                (double*)&A[0][0],
                (double*)&B[0][0]);
  }

  /* Be clean. */
  std::free(C);
  std::free(A);
  std::free(B);
}

// Register the function as a benchmark
BENCHMARK(BM_GEMM)->Unit(benchmark::kMillisecond)->Iterations(1)->ReportAggregatesOnly(true);

// Run the benchmark
BENCHMARK_MAIN();
