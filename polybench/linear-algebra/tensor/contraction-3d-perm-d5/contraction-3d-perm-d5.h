#ifndef _TENSORCONTRACTION_PERM_D5_H
# define _TENSORCONTRACTION_PERM_D5_H

/* Default to LARGE_DATASET. */
# if !defined(MINI_DATASET) && !defined(SMALL_DATASET) && !defined(MEDIUM_DATASET) && !defined(LARGE_DATASET) && !defined(EXTRALARGE_DATASET)
#  define LARGE_DATASET
# endif

# if !defined(A_D_1) && !defined(A_D_2) && !defined(A_D_3) && !defined(B_D_1) && !defined(B_D_2) &&!defined(B_D_3)
/* Define sample dataset sizes. */
#  ifdef MINI_DATASET
#   define A_D_1 30
#   define A_D_2 40
#   define A_D_3 20
#   define B_D_1 40
#   define B_D_2 30
#   define B_D_3 20
#  endif

#  ifdef SMALL_DATASET
#   define A_D_1 40
#   define A_D_2 60
#   define A_D_3 30
#   define B_D_1 60
#   define B_D_2 40
#   define B_D_3 30
#  endif

#  ifdef MEDIUM_DATASET
#   define A_D_1 60
#   define A_D_2 80
#   define A_D_3 40
#   define B_D_1 80
#   define B_D_2 60
#   define B_D_3 50
#  endif

#  ifdef LARGE_DATASET
#   define A_D_1 80
#   define A_D_2 10001
#   define A_D_3 50
#   define B_D_1 10001
#   define B_D_2 80
#   define B_D_3 60
#  endif

#  ifdef EXTRALARGE_DATASET
#   define A_D_1 80
#   define A_D_2 100
#   define A_D_3 50
#   define B_D_1 100
#   define B_D_2 80
#   define B_D_3 60
#  endif


#endif /* !(NI NJ NK NL) */

# define _PB_A_D_1 POLYBENCH_LOOP_BOUND(A_D_1,a_d_1)
# define _PB_A_D_2 POLYBENCH_LOOP_BOUND(A_D_2,a_d_2)
# define _PB_A_D_3 POLYBENCH_LOOP_BOUND(A_D_3,a_d_3)
# define _PB_B_D_1 POLYBENCH_LOOP_BOUND(B_D_1,b_d_1)
# define _PB_B_D_2 POLYBENCH_LOOP_BOUND(B_D_2,b_d_2)
# define _PB_B_D_3 POLYBENCH_LOOP_BOUND(B_D_3,b_d_3)


/* Default data type */
# if !defined(DATA_TYPE_IS_INT) && !defined(DATA_TYPE_IS_FLOAT) && !defined(DATA_TYPE_IS_DOUBLE)
#  define DATA_TYPE_IS_DOUBLE
# endif

#ifdef DATA_TYPE_IS_INT
#  define DATA_TYPE int
#  define DATA_PRINTF_MODIFIER "%d "
#endif

#ifdef DATA_TYPE_IS_FLOAT
#  define DATA_TYPE float
#  define DATA_PRINTF_MODIFIER "%0.2f "
#  define SCALAR_VAL(x) x##f
#  define SQRT_FUN(x) sqrtf(x)
#  define EXP_FUN(x) expf(x)
#  define POW_FUN(x,y) powf(x,y)
# endif

#ifdef DATA_TYPE_IS_DOUBLE
#  define DATA_TYPE double
#  define DATA_PRINTF_MODIFIER "%0.2lf "
#  define SCALAR_VAL(x) x
#  define SQRT_FUN(x) sqrt(x)
#  define EXP_FUN(x) exp(x)
#  define POW_FUN(x,y) pow(x,y)
# endif

#endif /* !_2MM_H */
