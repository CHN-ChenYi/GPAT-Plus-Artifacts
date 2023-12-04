#!/bin/bash
# Process Polybench C files with polygeist

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

function Help() {
   echo "Translate polybench kernels from C to MLIR Affine"
   echo
   echo "Syntax: $(basename $0) -D DATASET_SIZE OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-h: print this Help."
   echo -e "\t-D [SIZE]: Specify size of dataset: MINI, SMALL, MEDIUM, LARGE, EXTRALARGE"
   echo -e "\t-v: Verbose mode."
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

  if [[ -z $MLIR_CLANG || ! -f $MLIR_CLANG ]]; then
    echo "mlir-clang not found!"
    exit 1
  fi

  if [[ -z $POLYGEIST_CLANG_HEADERS || ! -d $POLYGEIST_CLANG_HEADERS ]]; then
    echo "Polygeist clang headers not found!"
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

while getopts ":hvD:" option; do
  case $option in
    h)
      Help
      exit 0
      ;;
    D)
      DATASET_SIZE=${OPTARG}
      ;;
    v)
      set -x
      ;;
    \?)
      echo "Invalid option." >&2
      Help
      exit 1
      ;;
  esac
done

# Gets the last argument and checks if it is a directory.
OUTPUT_DIR=$BASH_ARGV
if [[ ! -d $OUTPUT_DIR || -z $OUTPUT_DIR ]]; then
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

# Source config and check dependencies
sourceConfigFile
checkDependencies

TMP_DIR="$OUTPUT_DIR/tmp/"
COPY_POLYBENCH_DIR="$TMP_DIR/polybench"

cd $POLYBENCH
mkdir -p $TMP_DIR

# Polybench Fix Step ---------------------------------------

# create tmp dir and copy polybench to there
cp -r $POLYBENCH $COPY_POLYBENCH_DIR

# remove static parameter in place from kernel function
for i in $(cat $POLYBENCH_BENCHMARK_LIST); do
  bench_file="$COPY_POLYBENCH_DIR/$i"

  STATIC_GREP=$(grep -n -B1 "void kernel_" $bench_file | grep static)
  # static not found (happens with doitgen)
  if [ $? != 0 ]; then
    continue
  fi
  STATIC_LINE=$(echo "$STATIC_GREP" | cut -d '-' -f1)
  sed -i "${STATIC_LINE}d" $bench_file
done

# Mlir-clang (Polygeist) Step ------------------------------

cd $OUTPUT_DIR

echoGreen "\nPOLYGEIST"
for i in $(cat $POLYBENCH_BENCHMARK_LIST); do
  FNAME=$(basename $i)
  echo -e " Polygeist (mlir-clang) $FNAME"
  KERNEL_NAME=$(echo "kernel_${FNAME%.*}" | tr '-' '_')
  bench_file="$COPY_POLYBENCH_DIR/$i"

  # check if benchmark exists
  if [ ! -f $bench_file ]; then
    continue
  fi

  # POLYBENCH_USE_RESTRICT: tell compiler there is no aliasing, does not seem to work, noalias is added later by packing pass
  $MLIR_CLANG $bench_file \
      --function=$KERNEL_NAME -D${DATASET_SIZE}_DATASET \
      -DPOLYBENCH_USE_SCALAR_LB -DPOLYBENCH_USE_RESTRICT -DPOLYBENCH_NO_FLUSH_CACHE \
      -I $POLYGEIST_CLANG_HEADERS -I $POLYBENCH_UTILITIES --raise-scf-to-affine \
      -S --memref-fullrank > $OUTPUT_DIR/${FNAME%.*}.tmp.mlir
  if [ $? -ne 0 ]; then
    echoRed "  (mlir-clang) Error: $FNAME" | tee -a $OUTPUT_DIR/error.txt
    continue
  fi

  # Affine-loop-pack does not pack here, only adds no-alias and fast-math to mlir kernels
  $MLIR_OPT \
      -affine-loop-pack="add-ffast-math=true add-no-alias=true packing-options=-1" \
      -affine-loop-normalize \
      -canonicalize \
      -affine-simplify-structures \
      -cse \
      "$OUTPUT_DIR/${FNAME%.*}.tmp.mlir" > "$OUTPUT_DIR/${FNAME%.*}.mlir"

  if [ $? -ne 0 ]; then
    echoRed "  (mlir-opt) Error: $FNAME" | tee -a $OUTPUT_DIR/error.txt
    continue
  fi

done

rm $OUTPUT_DIR/*.tmp.mlir
