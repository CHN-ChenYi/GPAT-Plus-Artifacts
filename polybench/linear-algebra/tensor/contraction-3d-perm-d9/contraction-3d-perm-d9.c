#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include "contraction-3d-perm-d9.h"
#include <polybench.h>


/* Array initialization. */
static
void init_array(int a_d_1, int a_d_2, int a_d_3, int b_d_1, int b_d_2, int b_d_3, 
                DATA_TYPE *alpha, DATA_TYPE *beta, 
                DATA_TYPE POLYBENCH_3D(A, A_D_1, A_D_2, A_D_3, a_d_1, a_d_2, a_d_3), 
                DATA_TYPE POLYBENCH_3D(B, B_D_1, B_D_2, B_D_3, b_d_1, b_d_2, b_d_3))
{
  *alpha = 1.5;
  *beta = 1.2;
  for (int i = 0; i < a_d_1; i++) {
    for (int j = 0; j < a_d_2; j++) {
        for (int k = 0; k < a_d_3; k++) {
            A[i][j][k] = (DATA_TYPE) ((i * j + k) % a_d_1 + a_d_2) / a_d_3;
        }
    }
  }

  for (int i = 0; i < b_d_1; i++) {
    for (int j = 0; j < b_d_2; j++) {
        for (int k = 0; k < b_d_3; k++) {
            B[i][j][k] = (DATA_TYPE) ((i * j + k) % b_d_1 + b_d_2) / b_d_3;
        }
    }
  }
}


/* DCE code. Must scan the entire live-out data.*/
static
void print_array(int a_d_3, int b_d_3,
		            DATA_TYPE POLYBENCH_2D(C, A_D_3, B_D_3, a_d_3, b_d_3))
{
  int i, j;

  POLYBENCH_DUMP_START;
  POLYBENCH_DUMP_BEGIN("C");
  for (i = 0; i < a_d_3; i++)
    for (j = 0; j < b_d_3; j++) {
      if ((i * a_d_3 + j) % 20 == 0) fprintf (POLYBENCH_DUMP_TARGET, "\n");
	  fprintf (POLYBENCH_DUMP_TARGET, DATA_PRINTF_MODIFIER, C[i][j]);
    }
  POLYBENCH_DUMP_END("C");
  POLYBENCH_DUMP_FINISH;
}



/* Main computational kernel. The whole function will be timed,
   including the call and return. */
static
void kernel_contraction_3d_perm_d9(int a_d_1, int a_d_2, int a_d_3,
                              int b_d_1, int b_d_2, int b_d_3,
                              DATA_TYPE POLYBENCH_2D(C, A_D_3, B_D_3, a_d_3, b_d_3),
                              DATA_TYPE POLYBENCH_3D(A, A_D_1, A_D_2, A_D_3, a_d_1, a_d_2, a_d_3),
                              DATA_TYPE POLYBENCH_3D(B, B_D_1, B_D_2, B_D_3, b_d_1, b_d_2, b_d_3)) {

#pragma scop
    for (int i = 0; i < _PB_A_D_3; i++) {
        for (int j = 0; j < _PB_B_D_3; j++) {
            C[i][j] = SCALAR_VAL(0.0);
        }
    }
    for (int i = 0; i < _PB_A_D_3; i++) {
        for (int k = 0; k < _PB_B_D_3; k++) {
            for (int m = 0; m < _PB_A_D_1 / 9; m++) {
                for (int n = 0; n < _PB_A_D_2; n++) {
                    C[i][k] += A[9 * m][n][i] * B[n][9 * m][k];
                }
            }
        }
    }
#pragma endscop
    return;
}



int main(int argc, char** argv)
{
  /* Retrieve problem size. */
  int a_d_1 = A_D_1;
  int a_d_2 = A_D_2;
  int a_d_3 = A_D_3;
  int b_d_1 = B_D_1;
  int b_d_2 = B_D_2;
  int b_d_3 = B_D_3;

  /* Variable declaration/allocation. */
  DATA_TYPE alpha;
  DATA_TYPE beta;


  POLYBENCH_3D_ARRAY_DECL(A, DATA_TYPE, A_D_1, A_D_2, A_D_3, a_d_1, a_d_2, a_d_3);
  POLYBENCH_3D_ARRAY_DECL(B, DATA_TYPE, B_D_1, B_D_2, B_D_3, b_d_1, b_d_2, b_d_3);
  POLYBENCH_2D_ARRAY_DECL(C, DATA_TYPE, A_D_3, B_D_3, a_d_3, b_d_3);
    

 
  /* Initialize array(s). */
  init_array (a_d_1, a_d_2, a_d_3, b_d_1, b_d_2, b_d_3, &alpha, &beta,
	            POLYBENCH_ARRAY(A),
	            POLYBENCH_ARRAY(B));

  /* Start timer. */
  polybench_start_instruments;

  /* Run kernel. */
  kernel_contraction_3d_perm_d9(a_d_1, a_d_2, a_d_3,
                           b_d_1, b_d_2, b_d_3,
                           POLYBENCH_ARRAY(C),
                           POLYBENCH_ARRAY(A),
                           POLYBENCH_ARRAY(B));


  /* Stop and print timer. */
  polybench_stop_instruments;
  polybench_print_instruments;


   /* Prevent dead-code elimination. All live-out data must be printed
     by the function call in argument. */
  polybench_prevent_dce(print_array(a_d_3, b_d_3,  POLYBENCH_ARRAY(C)));

  /* Be clean. */
  
  POLYBENCH_FREE_ARRAY(A);
  POLYBENCH_FREE_ARRAY(B);
  POLYBENCH_FREE_ARRAY(C);

  return 0;
}
