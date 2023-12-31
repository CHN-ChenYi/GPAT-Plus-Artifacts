#include "2mm.h"

void kernel_2mm(int ni, int nj, int nk, int nl,
  double alpha,
  double beta,
  double *tmp,
  double *A,
  double *B,
  double *C,
  double *D)
{
  int i, j, k;
  for (i = 0; i < NI; i++)
    for (j = 0; j < NJ; j++) {
      tmp[i * NJ + j] = 0.0;
      for (k = 0; k < NK; ++k)
        tmp[i * NJ + j] += alpha * A[i * NK + k] * B[k * NJ + j];
    }
  for (i = 0; i < NI; i++)
    for (j = 0; j < NL; j++) {
      D[i * NL + j] *= beta;
      for (k = 0; k < NJ; ++k)
        D[i * NL + j] += tmp[i * NJ + k] * C[k * NL + j];
    }
}