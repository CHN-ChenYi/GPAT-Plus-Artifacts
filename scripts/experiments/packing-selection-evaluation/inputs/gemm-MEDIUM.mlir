module attributes {llvm.data_layout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128", llvm.target_triple = "x86_64-unknown-linux-gnu"}  {
  func @kernel_gemm(%arg0: i32, %arg1: i32, %arg2: i32, %arg3: f64, %arg4: f64, %arg5: memref<200x220xf64> {llvm.noalias}, %arg6: memref<200x240xf64> {llvm.noalias}, %arg7: memref<240x220xf64> {llvm.noalias}) attributes {llvm.linkage = #llvm.linkage<external>} {
    affine.for %arg8 = 0 to 200 {
      affine.for %arg9 = 0 to 220 {
        %0 = affine.load %arg5[%arg8, %arg9] : memref<200x220xf64>
        %1 = arith.mulf %0, %arg4 {fastmathFlags = #llvm.fastmath<fast>} : f64
        affine.store %1, %arg5[%arg8, %arg9] : memref<200x220xf64>
      }
      affine.for %arg9 = 0 to 240 {
        affine.for %arg10 = 0 to 220 {
          %0 = affine.load %arg6[%arg8, %arg9] : memref<200x240xf64>
          %1 = arith.mulf %arg3, %0 {fastmathFlags = #llvm.fastmath<fast>} : f64
          %2 = affine.load %arg7[%arg9, %arg10] : memref<240x220xf64>
          %3 = arith.mulf %1, %2 {fastmathFlags = #llvm.fastmath<fast>} : f64
          %4 = affine.load %arg5[%arg8, %arg10] : memref<200x220xf64>
          %5 = arith.addf %4, %3 {fastmathFlags = #llvm.fastmath<fast>} : f64
          affine.store %5, %arg5[%arg8, %arg10] : memref<200x220xf64>
        }
      }
    }
    return
  }
}

