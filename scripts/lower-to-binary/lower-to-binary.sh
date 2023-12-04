#!/bin/bash
# Create a binary from .mlir kernel and polybench .c files

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
   echo "Compile .mlir Polybench kernels"
   echo
   echo "Syntax: $(basename $0) -D DATASIZE INPUT_MLIR_KERNELS OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-h: Print this Help."
   echo -e "\t-D [SIZE]: Specify size of dataset: MINI, SMALL, MEDIUM, LARGE, EXTRALARGE"
   echo -e "\t-v: Verbose mode."
   echo -e "\t--disable-vectorization: Disable vectorization in LLVM."
   echo -e "\t--disable-unrolling: Disable unrolling in LLVM."
   echo
}

function sourceConfigFile() {
  # Gets this script path.
  scriptPath=$(getScriptLocation)
  configFilePath="$scriptPath/../config.file"
  # Checks the config.file
  if [ ! -f $configFilePath ]
  then
      echo "Please create config.file"
      Help
      exit 2
  fi
  source $configFilePath
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

  if [[ -z $POLYBENCH || ! -d $POLYBENCH ]]; then
    echo "Polybench not found!"
    exit 1
  fi

  if [[ -z $POLYBENCH_UTILITIES || ! -d $POLYBENCH_UTILITIES ]]; then
    echo "Polybench utilities not found!"
    exit 1
  fi

  if [[ -z $POLYBENCH_BENCHMARK_LIST || ! -f $POLYBENCH_BENCHMARK_LIST ]]; then
    echo "Polybench benchmark list not found!"
    exit 1
  fi

  if [[ -z $CLANG || ! -f $CLANG ]]; then
    echo "clang not found!"
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
}

RED="\033[0;91m"
GREEN="\033[0;92m"
YEL="\033[0;93m"
CLR="\033[0m"

function echoRed() {
  echo -e "$RED$1$CLR"
}

function echoGreen() {
  echo -e "$GREEN$1$CLR"
}

function echoYellow() {
  echo -e "$YEL$1$CLR"
}

DATASET_SIZE=""
DISABLE_VECTORIZATION="false"
DISABLE_UNROLLING="false"

PARSED_ARGUMENTS=$(getopt -a -n "polly" -o hvD: --long disable-unrolling,disable-vectorization -- "$@")
if [ $? != 0 ]; then
    echo "Invalid option." >&2
    Help
    exit 1;
fi
eval set -- "$PARSED_ARGUMENTS"
while [ : ]; do
  case "$1" in
    -h)
      Help
      exit 0
      ;;
    -v)
      set -x
      shift
      ;;
    -D)
      DATASET_SIZE="$2"
      shift 2
      ;;
    --disable-vectorization)
      DISABLE_VECTORIZATION="true"
      shift
      ;;
    --disable-unrolling)
      DISABLE_UNROLLING="true"
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "Unexpected option: $1"
      Help
      exit 1
      ;;
  esac
done

# Gets the last argument and checks if it is a directory.
OUTPUT_DIR=${BASH_ARGV[0]}
if [[ ! -d $OUTPUT_DIR ]] || [[ -z $OUTPUT_DIR ]]; then
    echo "ERROR: Output path is empty or isn't a directory."
    Help
    exit 1
fi
OUTPUT_DIR=$(realpath $OUTPUT_DIR)

# Gets the second last argument and checks if it is a directory.
INPUT_DIR=${BASH_ARGV[1]}
if [[ ! -d $INPUT_DIR ]] || [[ -z $INPUT_DIR ]]; then
    echo "ERROR: Input path is empty or isn't a directory."
    Help
    exit 1
fi
INPUT_DIR=$(realpath $INPUT_DIR)

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

# Source config and check dependencies and check clang version
sourceConfigFile
checkDependencies
checkClangVersion

# Get remove-body.py script path
REMOVE_BODY="$scriptPath/remove-body.py"
if [ ! -f $REMOVE_BODY ]; then
  echo "remove-body.py not found!"
  exit 1
fi
REMOVE_BODY=$(realpath $REMOVE_BODY)

TMP_DIR="$OUTPUT_DIR/tmp"
COPY_POLYBENCH_DIR="$TMP_DIR/polybench"
ERROR_FILE="$OUTPUT_DIR/error.txt"

cd $OUTPUT_DIR
mkdir -p $TMP_DIR

# Polybench Adaptation ---------------------------------------

# create tmp dir and copy polybench to there
cp -r $POLYBENCH $COPY_POLYBENCH_DIR

for i in $(cat $POLYBENCH_BENCHMARK_LIST); do
  # remove static parameter in place from kernel function
  STATIC_GREP=$(grep -n -B1 "void kernel_" $COPY_POLYBENCH_DIR/$i | grep static)
  # static found (does not happen with doitgen)
  if [ $? == 0 ]; then
    STATIC_LINE=$(echo "$STATIC_GREP" | cut -d '-' -f1)
    sed -i "${STATIC_LINE}d" $COPY_POLYBENCH_DIR/$i
  fi

  # remove body of kernel function and only leave a function declaration
  $REMOVE_BODY $COPY_POLYBENCH_DIR/$i

done

FLAGS=""

if [[ $DISABLE_VECTORIZATION == "true" ]]; then
  FLAGS="$FLAGS -fno-vectorize -fno-slp-vectorize -fno-tree-vectorize"
else
  FLAGS="$FLAGS -march=native"
fi

if [[ $DISABLE_UNROLLING == "true" ]]; then
  FLAGS="$FLAGS -fno-unroll-loops"
fi

# Compile .mlir with .c files -------------------------------

for i in $(cat $POLYBENCH_BENCHMARK_LIST); do
  FNAME=$(basename $i)

  # Check if polybench kernel and mlir input exist
  if [[ ! -f $COPY_POLYBENCH_DIR/$i || ! -f $INPUT_DIR/${FNAME%.*}.mlir ]]; then
    continue
  fi

  echo -e " Lowering and compiling (mlir-opt mlir-translate clang) $FNAME and ${FNAME%.*}.mlir"
  cp $INPUT_DIR/${FNAME%.*}.mlir $OUTPUT_DIR/${FNAME%.*}.mlir

  # Lower affine to the llvm dialect
  $MLIR_OPT $OUTPUT_DIR/${FNAME%.*}.mlir \
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
    -o $OUTPUT_DIR/${FNAME%.*}.llvmir.mlir
  if [ $? -ne 0 ]; then
    echoRed "  (mlir-opt lowering) Error: $FNAME" | tee -a $ERROR_FILE
    continue
  fi

  # translate llvm dialect to llvm ir
  $MLIR_TRANSLATE \
    $OUTPUT_DIR/${FNAME%.*}.llvmir.mlir \
    -mlir-to-llvmir \
    -o $OUTPUT_DIR/${FNAME%.*}.no-opt.ll
  if [ $? -ne 0 ]; then
    echoRed "  (mlir-translate) Error: $FNAME" | tee -a $ERROR_FILE
    continue
  fi

  # compile the kernel
  $CLANG -c $OUTPUT_DIR/${FNAME%.*}.no-opt.ll \
    -Wall -Wno-unused-variable -Wno-unknown-pragmas \
    -O3 -ffast-math $FLAGS -emit-llvm -S -flto \
    -o $OUTPUT_DIR/${FNAME%.*}.ll
  if [ $? -ne 0 ]; then
    echoRed "  (clang/compile) Error: $FNAME" | tee -a $ERROR_FILE
    continue
  fi

  # compile and link kernel with polybench
  # input files must come first in the command
  # -lm is required for a few kernels
  $CLANG $COPY_POLYBENCH_DIR/$i $OUTPUT_DIR/${FNAME%.*}.ll $POLYBENCH_UTILITIES/polybench.c \
    -I$POLYBENCH_UTILITIES -I$COPY_POLYBENCH_DIR/$(dirname $i) \
    -DPOLYBENCH_USE_RESTRICT -DPOLYBENCH_TIME -D${DATASET_SIZE}_DATASET -DPOLYBENCH_NO_FLUSH_CACHE \
    -Wall -Wno-misleading-indentation -Wno-unused-variable -Wno-unknown-pragmas \
    -O3 -ffast-math $FLAGS -flto -lm \
    -o $OUTPUT_DIR/${FNAME%.*}.exe
  if [ $? -ne 0 ]; then
    echoRed "  (clang/link) Error: $FNAME" | tee -a $ERROR_FILE
    continue
  fi

done

rm -f $OUTPUT_DIR/*.mlir $OUTPUT_DIR/*.no-opt.ll
