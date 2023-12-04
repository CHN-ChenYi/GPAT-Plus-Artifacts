#!/bin/bash
# Compile polybench with polly

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
   echo "Compile polybench kernels from C with LLVM's Polly"
   echo
   echo "Syntax: $(basename $0) -D DATASET_SIZE OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-D [SIZE]: Specify size of dataset: MINI, SMALL, MEDUIM, LARGE, EXTRALARGE"
   echo -e "\t-h: Print this Help."
   echo -e "\t-v: Verbose mode."
   echo -e "\t--l1 [SIZE]: Specify L1 cache size in KiB. Default is 32."
   echo -e "\t--l2 [SIZE]: Specify L2 cache size in KiB. Default is 256."
   echo -e "\t--l1-associativity [SIZE]: Specify L1 cache associativity. Default is 8."
   echo -e "\t--l2-associativity [SIZE]: Specify L2 cache associativity. Default is 8."
   echo -e "\t--enable-pattern-matching: Enable pattern matching optimizations in Polly."
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
L1="32"
L2="256"
L1_ASSOCIATIVITY="8"
L2_ASSOCIATIVITY="8"
ENABLE_PATTERN_MATCHING="false"
DISABLE_VECTORIZATION="false"
DISABLE_UNROLLING="false"

PARSED_ARGUMENTS=$(getopt -a -n "polly" -o hvD: --long l1:,l2:,l1-associativity:,l2-associativity:,enable-pattern-matching,disable-unrolling,disable-vectorization -- "$@")
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
    --l1)
      L1="$2"
      shift 2
      ;;
    --l2)
      L2="$2"
      shift 2
      ;;
    --l1-associativity)
      L1_ASSOCIATIVITY="$2"
      shift 2
      ;;
    --l2-associativity)
      L2_ASSOCIATIVITY="$2"
      shift 2
      ;;
    --enable-pattern-matching)
      ENABLE_PATTERN_MATCHING="true"
      shift
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

ERROR_FILE="$OUTPUT_DIR/error.txt"
mkdir -p $OUTPUT_DIR
cd $OUTPUT_DIR

FLAGS=""

if [[ $DISABLE_VECTORIZATION == "true" ]]; then
  FLAGS="$FLAGS -fno-vectorize -fno-slp-vectorize -fno-tree-vectorize"
else
  FLAGS="$FLAGS -march=native"
fi

if [[ $DISABLE_UNROLLING == "true" ]]; then
  FLAGS="$FLAGS -fno-unroll-loops"
fi

for i in $(cat $POLYBENCH_BENCHMARK_LIST); do
  FNAME=$(basename $i)
  echo -e " Polly (clang) $FNAME"
  KERNEL_NAME=$(echo "kernel_${FNAME%.*}" | tr '-' '_')
  bench_file="$POLYBENCH/$i"

  # check if benchmark exists
  if [ ! -f $bench_file ]; then
    continue
  fi

  # Compile kernel with polly
  $CLANG -c $bench_file \
    -I$POLYBENCH_UTILITIES -DPOLYBENCH_USE_SCALAR_LB \
    -DPOLYBENCH_USE_RESTRICT -DPOLYBENCH_NO_FLUSH_CACHE \
    -D${DATASET_SIZE}_DATASET -DPOLYBENCH_TIME \
    -Wall -Wno-misleading-indentation -Wno-unused-variable -Wno-unknown-pragmas \
    -O3 -ffast-math $FLAGS \
    -mllvm -polly \
    -mllvm -polly-pattern-matching-based-opts=${ENABLE_PATTERN_MATCHING} \
    -mllvm -polly-target-1st-cache-level-associativity=${L1_ASSOCIATIVITY} \
    -mllvm -polly-target-2nd-cache-level-associativity=${L2_ASSOCIATIVITY} \
    -mllvm -polly-target-1st-cache-level-size=$(($L1*1024)) \
    -mllvm -polly-target-2nd-cache-level-size=$(($L2*1024)) \
    -emit-llvm -S -flto \
    -o $OUTPUT_DIR/${FNAME%.*}.ll

  if [ $? -ne 0 ]; then
    echoRed "  (clang/compile) Error: $FNAME" | tee -a $ERROR_FILE
    continue
  fi

  $CLANG "$OUTPUT_DIR/${FNAME%.*}.ll" "$POLYBENCH_UTILITIES/polybench.c" \
    -I$POLYBENCH_UTILITIES -DPOLYBENCH_USE_SCALAR_LB \
    -DPOLYBENCH_USE_RESTRICT -DPOLYBENCH_NO_FLUSH_CACHE \
    -D${DATASET}_DATASET -DPOLYBENCH_TIME \
    -Wall -Wno-unused-variable -Wno-unknown-pragmas \
    -O3 -ffast-math $FLAGS -flto -lm \
    -o $OUTPUT_DIR/${FNAME%.*}.exe
  
  if [ $? -ne 0 ]; then
    echoRed "  (clang/link) Error: $FNAME" | tee -a $ERROR_FILE
    continue
  fi
done
