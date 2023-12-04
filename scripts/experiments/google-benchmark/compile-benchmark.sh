#! /usr/bin/env bash
# Run a benchmark file with google benchmark

# Gets the location of the script
function getScriptLocation {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        SOURCE="$(readlink "$SOURCE")"
        [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
    done
        DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
        echo $DIR
}

function Help()
{
  echo "Compile a benchmark file with google benchmark"
  echo
  echo "Syntax: $(basename $0) -D DATASET_SIZE -M MODE -B BENCHMARK_NAME INPUT OUTPUT_DIR"
  echo "Options:"
  echo -e "\t-D [SIZE]: Specify size of dataset: MINI, SMALL, MEDUIM, LARGE, EXTRALARGE"
  echo -e "\t-M [MODE]: Specify mode of execution:"
  echo -e "\t\tCLANG: compile c file using clang"
  echo -e "\t\tPOLLY: compile c file using polly"
  echo -e "\t\tMLIR: compile mlir file"
  echo -e "\t-B [BENCHMARK]: Specify benchmark name:"
  echo -e "\t\tgemm"
  echo -e "\t\t2mm"
  echo -e "\t-h: Print this Help."
  echo -e "\t-v: Verbose mode."
  echo
  echo "For modes CLANG and POLLY use the gemm.c or 2mm.c files provided in this folder as input"
  echo "For mode MLIR use any .mlir file as input"
  echo
}

function sourceConfigFile() {
  # Gets this script path.
  scriptPath=$(getScriptLocation)
  configFilePath="$scriptPath/../../config.file"
  # Checks the config.file
  if [ ! -f $configFilePath ]
  then
      echo "Please create config.file"
      Help
      exit 2
  fi
  source $configFilePath
}

function sourceSpecFile() {
  # Gets this script path.
  scriptPath=$(getScriptLocation)
  specFilePath="$scriptPath/../spec.file"
  # Checks the spec.file
  if [ ! -f $specFilePath ]
  then
      echo "Please create spec.file"
      Help
      exit 2
  fi
  source $specFilePath
}

function checkDependencies() {
  if [[ -z $MLIR_OPT || ! -f $MLIR_OPT ]]; then
    echo "mlir-opt not found!"
    exit 1
  fi

  if [[ -z $MLIR_TRANSLATE || ! -f $MLIR_TRANSLATE ]]; then
    echo "mlir-translate not found!"
    exit 1
  fi

  if [[ -z $CLANG || ! -f $CLANG ]]; then
    echo "clang not found!"
    exit 1
  fi

  if [[ -z $CLANGPP || ! -f $CLANGPP ]]; then
    echo "clang not found!"
    exit 1
  fi
}

function checkSpecs() {
  if [[ -z $L1 ]]; then
    echo "L1 size not defined"
    exit 1
  fi

  if [[ -z $L2 ]]; then
    echo "L2 size not defined"
    exit 1
  fi

  if [[ -z $L1_ASSOCIATIVITY ]]; then
    echo "L1 associativity not defined"
    exit 1
  fi

  if [[ -z $L2_ASSOCIATIVITY ]]; then
    echo "L2 associativity not defined"
    exit 1
  fi

  if [[ -z $POLLY_ENABLE_PATTERN_MATCHING ]]; then
    echo "Polly enable pattern matching not defined"
    exit 1
  fi

  if [[ -z $LLVM_DISABLE_VECTORIZATION ]]; then
    echo "LLVM disable vectorization not defined"
    exit 1
  fi

  if [[ -z $LLVM_DISABLE_UNROLLING ]]; then
    echo "LLVM disable unrolling not defined"
    exit 1
  fi
}

function checkClangVersion() {
  if [[ -z $CLANG_VERSION ]]; then
    echo "Clang version not defined!"
    exit 1
  fi

  # Check clang version
  $CLANG --version | grep -q --fixed-strings $CLANG_VERSION
  if [[ $? -ne 0 ]]; then
    echo "Incorrect clang version, please set it up according to the config.file"
    echo "Corrent version is $CLANG_VERSION"
    exit 1
  fi

  # Check clang version
  $CLANGPP --version | grep -q --fixed-strings $CLANG_VERSION
  if [[ $? -ne 0 ]]; then
    echo "Incorrect clang++ version, please set it up according to the config.file"
    echo "Corrent version is $CLANG_VERSION"
    exit 1
  fi
}

DATASET_SIZE=""
MODE=""
BENCHMARK_NAME=""

while getopts ":hvD:M:B:" option; do
  case $option in
    h)
      Help
      exit 0
      ;;
    v)
      set -x
      ;;
    D)
      DATASET_SIZE=${OPTARG}
      ;;
    M)
      MODE=${OPTARG}
      ;;
    B)
      BENCHMARK_NAME=${OPTARG}
      ;;
    \?)
      echo "Invalid option." >&2
      Help
      exit 1
      ;;
  esac
done

# Gets the last argument and checks if it is a directory.
OUTPUT_DIR=${BASH_ARGV[0]}
if [[ -z $OUTPUT_DIR ]] || [[ ! -d $OUTPUT_DIR ]]; then
    echo "ERROR: Output path is empty or isn't a directory."
    Help
    exit 1
fi
OUTPUT_DIR=$(realpath $OUTPUT_DIR)

# Gets the last argument and checks if it is a directory.
INPUT_FILE=${BASH_ARGV[1]}
if [[ -z $INPUT_FILE ]] || [[ ! -f $INPUT_FILE ]]; then
    echo "ERROR: Input file is empty or isn't a directory."
    Help
    exit 1
fi
INPUT_FILE=$(realpath $INPUT_FILE)

# Check dataset size
case $DATASET_SIZE in
  (MINI|SMALL|MEDIUM|LARGE|EXTRALARGE)
  ;;
  *)
    echo "Please choose a valid dataset size selection"
    echo "Use MINI, SMALL, MEDIUM, LARGE, or EXTRALARGE"
    exit 1
  ;;
esac

# Check dataset size
case $MODE in
  (CLANG|POLLY|MLIR)
  ;;
  *)
    echo "Please choose a valid mode of execution"
    echo "Use CLANG, POLLY, or MLIR"
    exit 1
  ;;
esac

# Check benchmark name
case $BENCHMARK_NAME in
  (2mm|gemm)
  ;;
  *)
    echo "Please choose a valid benchmark name"
    echo "Use 2mm or gemm"
    exit 1
  ;;
esac

# Source config and spec, check dependencies, and check clang version
sourceConfigFile
sourceSpecFile
checkSpecs
checkDependencies
checkClangVersion

GOOGLE_BENCHMARK_FLAGS=""
# these flags are needed if google benchmark is not global
if [ ! -z $GOOGLE_BENCHMARK_INSTALL ]; then
  GOOGLE_BENCHMARK_FLAGS="-isystem $GOOGLE_BENCHMARK_INSTALL/include -L$GOOGLE_BENCHMARK_INSTALL/lib"
fi

# get name_benchmark.cpp path
BENCHMARK_DRIVER="$scriptPath/${BENCHMARK_NAME}/${BENCHMARK_NAME}_benchmark_driver.cpp"
if [ ! -f $BENCHMARK_DRIVER ]; then
  echo "${BENCHMARK_NAME}_benchmark_driver.cpp not found!"
  exit 1
fi
BENCHMARK_DRIVER=$(realpath $BENCHMARK_DRIVER)

FLAGS=""
if [[ $LLVM_DISABLE_VECTORIZATION == "true" ]]; then
  FLAGS="$FLAGS -fno-vectorize -fno-slp-vectorize -fno-tree-vectorize"
else
  FLAGS="$FLAGS -march=native"
fi
if [[ $LLVM_DISABLE_UNROLLING == "true" ]]; then
  FLAGS="$FLAGS -fno-unroll-loops"
fi

FILE_NAME=$(basename $INPUT_FILE)
FILE_NAME=${FILE_NAME%.*}

if [ $MODE == "MLIR" ]; then

  $MLIR_OPT $INPUT_FILE \
    -affine-loop-invariant-code-motion \
    -affine-loop-normalize \
    -canonicalize \
    -affine-simplify-structures \
    -cse \
    -lower-affine \
    -convert-scf-to-cf \
    -convert-arith-to-llvm \
    -convert-math-to-llvm \
    -convert-func-to-llvm="use-bare-ptr-memref-call-conv=1" \
    -convert-memref-to-llvm \
    -reconcile-unrealized-casts \
    -o $OUTPUT_DIR/${FILE_NAME}.llvmir.mlir
  if [ $? -ne 0 ]; then
    echo "mlir-opt lowering error"
    exit 1
  fi

  # translate llvm dialect to llvm ir
  $MLIR_TRANSLATE \
    $OUTPUT_DIR/${FILE_NAME}.llvmir.mlir \
    -mlir-to-llvmir \
    -o $OUTPUT_DIR/${FILE_NAME}.no-opt.ll
  if [ $? -ne 0 ]; then
    echo "mlir-translate error"
    exit 1
  fi

  $CLANG -c $OUTPUT_DIR/${FILE_NAME}.no-opt.ll \
    -Wall -Wno-unused-variable -Wno-unknown-pragmas \
    -O3 -ffast-math $FLAGS -emit-llvm -S -flto \
    -o $OUTPUT_DIR/${FILE_NAME}.ll

  if [ $? -ne 0 ]; then
    echo "clang/compile error"
    exit 1
  fi

  $CLANGPP $OUTPUT_DIR/${FILE_NAME}.ll -D$DATASET_SIZE $BENCHMARK_DRIVER \
    -std=c++11 -Wall -O3 -ffast-math $FLAGS -flto \
    $GOOGLE_BENCHMARK_FLAGS -lm -lbenchmark -lpthread \
    -o $OUTPUT_DIR/${FILE_NAME}.exe

  if [ $? -ne 0 ]; then
    echo "clangpp/compile/link error"
    exit 1
  fi

  rm $OUTPUT_DIR/${FILE_NAME}.llvmir.mlir $OUTPUT_DIR/${FILE_NAME}.no-opt.ll

elif [ $MODE == "POLLY" ]; then

  $CLANG -c $INPUT_FILE \
    -D$DATASET_SIZE \
    -Wall -O3 -ffast-math $FLAGS \
    -mllvm -polly \
    -mllvm -polly-pattern-matching-based-opts="$POLLY_ENABLE_PATTERN_MATCHING" \
    -mllvm -polly-target-1st-cache-level-associativity="$L1_ASSOCIATIVITY" \
    -mllvm -polly-target-2nd-cache-level-associativity="$L2_ASSOCIATIVITY" \
    -mllvm -polly-target-1st-cache-level-size="$(($L1*1024))" \
    -mllvm -polly-target-2nd-cache-level-size="$(($L2*1024))" \
    -emit-llvm -S -flto \
    -o $OUTPUT_DIR/${FILE_NAME}-polly.ll

  if [ $? -ne 0 ]; then
    echo "clang/compile error"
    exit 1
  fi

  $CLANGPP $OUTPUT_DIR/${FILE_NAME}-polly.ll $BENCHMARK_DRIVER \
    -D$DATASET_SIZE \
    -std=c++11 -Wall -O3 -ffast-math $FLAGS -flto \
    $GOOGLE_BENCHMARK_FLAGS -lm -lbenchmark -lpthread \
    -o $OUTPUT_DIR/${FILE_NAME}.exe

  if [ $? -ne 0 ]; then
    echo "clangpp/compile/link error"
    exit 1
  fi

elif [ $MODE == "CLANG" ]; then

  $CLANG -c $INPUT_FILE \
    -D$DATASET_SIZE \
    -Wall -O3 -ffast-math $FLAGS \
    -emit-llvm -S -flto \
    -o $OUTPUT_DIR/${FILE_NAME}.ll

  if [ $? -ne 0 ]; then
    echo "clang/compile error"
    exit 1
  fi

  $CLANGPP $OUTPUT_DIR/${FILE_NAME}.ll $BENCHMARK_DRIVER \
    -D$DATASET_SIZE \
    -std=c++11 -Wall -O3 -ffast-math $FLAGS -flto \
    $GOOGLE_BENCHMARK_FLAGS -lm -lbenchmark -lpthread \
    -o $OUTPUT_DIR/${FILE_NAME}.exe

  if [ $? -ne 0 ]; then
    echo "clangpp/compile/link error"
    exit 1
  fi

fi
