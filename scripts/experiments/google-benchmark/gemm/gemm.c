#include "gemm.h"

void kernel_gemm(int ni, int nj, int nk,
  double alpha,
  double beta,
  double *C,
  double *A,
  double *B)
{
  int i, j, k;
  for (i = 0; i < NI; i++) {
    for (j = 0; j < NJ; j++)
      C[i * NJ + j] *= beta;
    for (k = 0; k < NK; k++) {
      for (j = 0; j < NJ; j++)
        C[i * NJ + j] += alpha * A[i * NK + k] * B[k * NJ + j];
    }
  }
}
