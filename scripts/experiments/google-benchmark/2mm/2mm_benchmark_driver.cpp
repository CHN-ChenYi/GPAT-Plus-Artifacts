#include <iostream>
#include <benchmark/benchmark.h>
#include "2mm.h"

/* Array initialization. */
void init_array(int ni, int nj, int nk, int nl,
  double *alpha,
  double *beta,
  double A[NI][NK],
  double B[NK][NJ],
  double C[NJ][NL],
  double D[NI][NL])
{
  int i, j;

  *alpha = 1.5;
  *beta = 1.2;
  for (i = 0; i < ni; i++)
    for (j = 0; j < nk; j++)
      A[i][j] = (double) (i*j % ni) / ni;
  for (i = 0; i < nk; i++)
    for (j = 0; j < nj; j++)
      B[i][j] = (double) (i*(j+1) % nj) / nj;
  for (i = 0; i < nj; i++)
    for (j = 0; j < nl; j++)
      C[i][j] = (double) (i*(j+3) % nl) / nl;
  for (i = 0; i < ni; i++)
    for (j = 0; j < nl; j++)
      D[i][j] = (double) (i*(j+2) % nk) / nk;
}

extern "C" void kernel_2mm(int ni, int nj, int nk, int nl,
                           double alpha,
                           double beta,
                           double *tmp,
                           double *A,
                           double *B,
                           double *C,
                           double *D);

static void BM_2MM(benchmark::State& state) {
  /* Retrieve problem size. */
  int ni = NI;
  int nj = NJ;
  int nk = NK;
  int nl = NL;

  /* Variable declaration/allocation. */
  double alpha;
  double beta;
  double (*tmp)[NI][NJ];
  double (*A)[NI][NK];
  double (*B)[NK][NJ];
  double (*C)[NJ][NL];
  double (*D)[NI][NL];

  tmp = (double(*)[NI][NJ]) aligned_alloc(1024, (NI) * (NJ) * sizeof(double));;
  A = (double(*)[NI][NK]) aligned_alloc(1024, (NI) * (NK) * sizeof(double));;
  B = (double(*)[NK][NJ]) aligned_alloc(1024, (NK) * (NJ) * sizeof(double));;
  C = (double(*)[NJ][NL]) aligned_alloc(1024, (NJ) * (NL) * sizeof(double));;
  D = (double(*)[NI][NL]) aligned_alloc(1024, (NI) * (NL) * sizeof(double));;

  /* Initialize array(s). */
  init_array (ni, nj, nk, nl, &alpha, &beta,
              *A,
              *B,
              *C,
              *D);


  for (auto _ : state) {
    /* Run kernel. */
    kernel_2mm(ni, nj, nk, nl,
                alpha, beta,
                (double*)&tmp[0][0],
                (double*)&A[0][0],
                (double*)&B[0][0],
                (double*)&C[0][0],
                (double*)&D[0][0]);
  }

  /* Be clean. */
  std::free(tmp);
  std::free(A);
  std::free(B);
  std::free(C);
  std::free(D);
}

// Register the function as a benchmark
BENCHMARK(BM_2MM)->Unit(benchmark::kMillisecond)->Iterations(1)->ReportAggregatesOnly(true);

// Run the benchmark
BENCHMARK_MAIN();
