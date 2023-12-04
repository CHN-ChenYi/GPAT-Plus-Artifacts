module attributes {dlti.dl_spec = #dlti.dl_spec<#dlti.dl_entry<"dlti.endianness", "little">, #dlti.dl_entry<i64, dense<64> : vector<2xi32>>, #dlti.dl_entry<f80, dense<128> : vector<2xi32>>, #dlti.dl_entry<i1, dense<8> : vector<2xi32>>, #dlti.dl_entry<i8, dense<8> : vector<2xi32>>, #dlti.dl_entry<i16, dense<16> : vector<2xi32>>, #dlti.dl_entry<i32, dense<32> : vector<2xi32>>, #dlti.dl_entry<f16, dense<16> : vector<2xi32>>, #dlti.dl_entry<f64, dense<64> : vector<2xi32>>, #dlti.dl_entry<f128, dense<128> : vector<2xi32>>>, llvm.data_layout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-f80:128-n8:16:32:64-S128", llvm.target_triple = "x86_64-unknown-linux-gnu"} {
  func @kernel_2mm(%arg0: i32, %arg1: i32, %arg2: i32, %arg3: i32, %arg4: f64, %arg5: f64, %arg6: memref<40x50xf64> {llvm.noalias}, %arg7: memref<40x70xf64> {llvm.noalias}, %arg8: memref<70x50xf64> {llvm.noalias}, %arg9: memref<50x80xf64> {llvm.noalias}, %arg10: memref<40x80xf64> {llvm.noalias}) attributes {llvm.linkage = #llvm.linkage<external>} {
    %cst = arith.constant 0.000000e+00 : f64
    affine.for %arg11 = 0 to 40 {
      affine.for %arg12 = 0 to 50 {
        affine.store %cst, %arg6[%arg11, %arg12] : memref<40x50xf64>
        affine.for %arg13 = 0 to 70 {
          %0 = affine.load %arg7[%arg11, %arg13] : memref<40x70xf64>
          %1 = arith.mulf %arg4, %0 {fastmathFlags = #llvm.fastmath<fast>} : f64
          %2 = affine.load %arg8[%arg13, %arg12] : memref<70x50xf64>
          %3 = arith.mulf %1, %2 {fastmathFlags = #llvm.fastmath<fast>} : f64
          %4 = affine.load %arg6[%arg11, %arg12] : memref<40x50xf64>
          %5 = arith.addf %4, %3 {fastmathFlags = #llvm.fastmath<fast>} : f64
          affine.store %5, %arg6[%arg11, %arg12] : memref<40x50xf64>
        }
      }
    }
    affine.for %arg11 = 0 to 40 {
      affine.for %arg12 = 0 to 80 {
        %0 = affine.load %arg10[%arg11, %arg12] : memref<40x80xf64>
        %1 = arith.mulf %0, %arg5 {fastmathFlags = #llvm.fastmath<fast>} : f64
        affine.store %1, %arg10[%arg11, %arg12] : memref<40x80xf64>
        affine.for %arg13 = 0 to 50 {
          %2 = affine.load %arg6[%arg11, %arg13] : memref<40x50xf64>
          %3 = affine.load %arg9[%arg13, %arg12] : memref<50x80xf64>
          %4 = arith.mulf %2, %3 {fastmathFlags = #llvm.fastmath<fast>} : f64
          %5 = affine.load %arg10[%arg11, %arg12] : memref<40x80xf64>
          %6 = arith.addf %5, %4 {fastmathFlags = #llvm.fastmath<fast>} : f64
          affine.store %6, %arg10[%arg11, %arg12] : memref<40x80xf64>
        }
      }
    }
    return
  }
}

