#!/bin/bash
# Generate multiple tilings of a .mlir file using Polymer and apply multiple packings to them

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
   echo "Generate multiple tilings of a .mlir file using Polymer and apply multiple packings to them"
   echo
   echo "Syntax: $(basename $0) -D DATASET_SIZE -B BENCHMARK_NAME OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-D [SIZE]: Specify size of dataset: MINI, SMALL, MEDUIM, LARGE, EXTRALARGE"
   echo -e "\t-B [BENCHMARK]: Specify benchmark name:"
   echo -e "\t\tgemm"
   echo -e "\t\tgemm-blis"
   echo -e "\t\t2mm"
   echo -e "\t-h: Print this Help."
   echo -e "\t-v: Verbose mode."
   echo
   echo -e "Tiling sizes generated by default are:"
   echo -e "\tMINI:       2  - 8    in increments of 1"
   echo -e "\tSMALL:      2  - 32   in increments of 1"
   echo -e "\tMEDIUM:     4  - 128  in increments of 1"
   echo -e "\tLARGE:      8  - 512  in increments of 2"
   echo -e "\tEXTRALARGE: 16 - 1024 in increments of 4"
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

function checkSpecs() {
  if [[ -z $L1 ]]; then
    echo "L1 size not defined"
    exit 1
  fi

  if [[ -z $L2 ]]; then
    echo "L2 size not defined"
    exit 1
  fi

  if [[ -z $L3 ]]; then
    echo "L3 size not defined"
    exit 1
  fi

  if [[ -z $CACHE_LINE ]]; then
    echo "Cache line size not defined"
    exit 1
  fi

  if [[ -z $DTLB_ENTRY ]]; then
    echo "Number of dtlb entries not defined"
    exit 1
  fi

  if [[ -z $DTLB_PAGE ]]; then
    echo "Page size not defined"
    exit 1
  fi
}

function checkDependencies() {
  if [[ -z $MLIR_OPT || ! -f $MLIR_OPT ]]; then
    echo "mlir-opt not found!"
    exit 1
  fi

  if [[ -z $POLYMER_OPT || ! -f $POLYMER_OPT ]]; then
    echo "polymer-opt not found!"
    exit 1
  fi

  if [[ -z $POLYMER_PLUTO_LIB || ! -d $POLYMER_PLUTO_LIB ]]; then
    echo "Pluto lib not found!"
    exit 1
  fi

  # Check clang ahead, otherwise only checked in lowering
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

# https://stackoverflow.com/a/29886498
# swapFileLines lineNum1 lineNum2 file
swapFileLines() {
  [ "$1" -ge 1 ] || { printf "ARGUMENT ERROR: Line numbers must be decimal integers >= 1.\n" >&2; return 2; }
  [ "$1" -le "$2" ] || { printf "ARGUMENT ERROR: The first line number ($1) must be <= the second ($2).\n" >&2; return 2; }
  ed -s "$3" <<EOF
H
$1m$2
$2-m$1-
w
EOF
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
BENCHMARK_NAME=""

while getopts ":hvD:B:" option; do
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

# Check benchmark name
case $BENCHMARK_NAME in
  (2mm|gemm|gemm-blis)
  ;;
  *)
    echo "Please choose a valid benchmark name"
    echo "Use 2mm, gemm, or gemm-blis"
    exit 1
  ;;
esac

# Source config and spec, check dependencies, and check clang version
sourceConfigFile
sourceSpecFile
checkSpecs
checkDependencies
checkClangVersion

# Get compile-benchmark.sh path
COMPILE_BENCHMARK="$scriptPath/../google-benchmark/compile-benchmark.sh"
if [ ! -f $COMPILE_BENCHMARK ]; then
  echo "compile-benchmark.sh not found!"
  exit 1
fi
COMPILE_BENCHMARK=$(realpath $COMPILE_BENCHMARK)

# Gets the second last argument and checks if it is a directory.
INPUT_FILE="$scriptPath/inputs/${BENCHMARK_NAME%-*}-${DATASET_SIZE}.mlir"
if [ ! -f $INPUT_FILE ]; then
    echo "ERROR: Input not found!"
    exit 1
fi
INPUT_FILE=$(realpath $INPUT_FILE)

# Output paths
OUTPUT_TILINGS="$OUTPUT_DIR/tilings"
OUTPUT_PACKINGS="$OUTPUT_DIR/packings"
OUTPUT_PACKINGS_EXE="$OUTPUT_DIR/executables"

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${POLYMER_PLUTO_LIB}"

# Generate tilings ----------------------------------

case $DATASET_SIZE in
  MINI)
    INCREMENT="1"
    FIRST_SIZE="2"
    LAST_SIZE="8"
  ;;
  SMALL)
    INCREMENT="1"
    FIRST_SIZE="2"
    LAST_SIZE="32"
  ;;
  MEDIUM)
    INCREMENT="1"
    FIRST_SIZE="4"
    LAST_SIZE="128"
  ;;
  LARGE)
    INCREMENT="2"
    FIRST_SIZE="8"
    LAST_SIZE="512"
  ;;
  EXTRALARGE)
    INCREMENT="4"
    FIRST_SIZE="16"
    LAST_SIZE="1024"
  ;;
  *)
    echo "Not a valid tile size selection. Use MINI, SMALL, MEDIUM, LARGE, EXTRALARGE."
    exit 1
  ;;
esac

mkdir -p $OUTPUT_TILINGS
cd $OUTPUT_TILINGS

for tile in $(seq $FIRST_SIZE $INCREMENT $LAST_SIZE); do
  echoGreen "\nPOLYMER: TILE $tile"
  FNAME=$(basename $INPUT_FILE)
  echo -e " Polymer (polymer-opt) $FNAME with tile size $tile"

  # set tile sizes for pluto
  echo -e "${tile}\n${tile}\n${tile}" > $OUTPUT_TILINGS/tile.sizes

  timeout 20s $POLYMER_OPT $INPUT_FILE \
      -allow-unregistered-dialect \
      -insert-redundant-load \
      -extract-scop-stmt \
      -canonicalize \
      -pluto-opt \
      -inline \
      -canonicalize 2> /dev/null > "$OUTPUT_TILINGS/${FNAME%.*}.tmp.mlir"

  if [ $? -ne 0 ]; then
    echoRed "  (polymer-opt) Error: $FNAME $tile" | tee -a $OUTPUT_TILINGS/error.txt
    continue
  fi

  $MLIR_OPT \
      -affine-loop-normalize \
      -canonicalize \
      -affine-simplify-structures \
      -cse \
      "$OUTPUT_TILINGS/${FNAME%.*}.tmp.mlir" > "$OUTPUT_TILINGS/${FNAME%.*}-${tile}-${tile}-${tile}.mlir"

  if [ $? -ne 0 ]; then
    echoRed "  (mlir-opt) Error: $FNAME $tile" | tee -a $OUTPUT_TILINGS/error.txt
    continue
  fi

  # manually change lines to interchange loop order
  # from Polymer's (i,j,k,ii,kk,jj) and obtain BLIS ordering (j,k,i,j,i,k)
  if [[ $BENCHMARK_NAME == "gemm-blis" ]]; then
    # beginning of the file may change because of the maps
    start=$(grep -n "module" $OUTPUT_TILINGS/${FNAME%.*}-${tile}-${tile}-${tile}.mlir | cut -d ':' -f1)
    swapFileLines $((start-1+14)) $((start-1+15)) "$OUTPUT_TILINGS/${FNAME%.*}-${tile}-${tile}-${tile}.mlir"
    swapFileLines $((start-1+15)) $((start-1+16)) "$OUTPUT_TILINGS/${FNAME%.*}-${tile}-${tile}-${tile}.mlir"
    swapFileLines $((start-1+18)) $((start-1+19)) "$OUTPUT_TILINGS/${FNAME%.*}-${tile}-${tile}-${tile}.mlir"
    swapFileLines $((start-1+17)) $((start-1+18)) "$OUTPUT_TILINGS/${FNAME%.*}-${tile}-${tile}-${tile}.mlir"
  fi
done

rm $OUTPUT_TILINGS/*.tmp.mlir
rm $OUTPUT_TILINGS/tile.sizes

# Generate packings ----------------------------------

mkdir -p $OUTPUT_PACKINGS
cd $OUTPUT_PACKINGS
mkdir -p logs

# Set flags to specs in spcs.file for GPAT version of packing
FLAGS="l1-cache-size=$L1 l2-cache-size=$L2 l3-cache-size=$L3 cache-line-size=$CACHE_LINE l1d-tlb-entries=$DTLB_ENTRY l1d-tlb-page-size=$DTLB_PAGE"

echoGreen "\nPACKING"
for i in $(find $OUTPUT_TILINGS -name "*.mlir" | sort); do
  FNAME=$(basename $i)
  echo -e " Packing multiple versions of (mlir-opt) $FNAME"

  # No packing version
  cp $i "$OUTPUT_PACKINGS/${FNAME%.*}-packing-none.mlir"

  # Get available packing options for this tiling
  packings=$($MLIR_OPT $i \
              -affine-loop-invariant-code-motion \
              -affine-loop-pack="ignore-cache ignore-contiguous-check ignore-tlb" \
              -debug-only="affine-loop-pack" 2>&1 | grep "Id" | grep --only-matching "[0-9]*" | sort -h | uniq)
  packing_list=($(echo $packings | tr '\n' ' '))

  # Individual packing options
  for packing_options in ${packing_list[@]}; do
    $MLIR_OPT $i \
        -affine-loop-invariant-code-motion \
        -affine-loop-pack="ignore-cache ignore-contiguous-check ignore-tlb packing-options=$packing_options" \
        -debug-only="affine-loop-pack" \
        -affine-loop-normalize \
        -canonicalize \
        -affine-simplify-structures \
        -cse \
        > "$OUTPUT_PACKINGS/${FNAME%.*}-packing-${packing_options}.mlir" 2> "logs/${FNAME%.*}-packing-${packing_options}.mlir.log"
    if [ $? -ne 0 ]; then
      echoRed "  (mlir-opt packing) Error: $FNAME $tile candidate $packing_options" | tee -a $OUTPUT_PACKINGS/error.txt
      continue
    fi
  done

  # Heuristic version (packing pass with all checks)
  $MLIR_OPT $i \
      -affine-loop-invariant-code-motion \
      -affine-loop-pack="$FLAGS" \
      -debug-only="affine-loop-pack" \
      -affine-loop-normalize \
      -canonicalize \
      -affine-simplify-structures \
      -cse \
      > "$OUTPUT_PACKINGS/${FNAME%.*}-packing-heuristic.mlir" 2> "logs/${FNAME%.*}-packing-heuristic.mlir.log"
    if [ $? -ne 0 ]; then
      echoRed "  (mlir-opt packing) Error: $FNAME $tile heuristic" | tee -a $OUTPUT_PACKINGS/error.txt
      continue
    fi

  # Delete heuristic version if it did not do any packing
  grep -q "Succeeded generating packing" "logs/${FNAME%.*}-packing-heuristic.mlir.log"
  if [ "$?" -eq "1" ]; then
    rm "$OUTPUT_PACKINGS/${FNAME%.*}-packing-heuristic.mlir"
  fi
done

# Compile executables ----------------------------------

mkdir -p $OUTPUT_PACKINGS_EXE
cd $OUTPUT_PACKINGS_EXE

echoGreen "\nGOOGLE BENCHMARK"
for i in $(find $OUTPUT_PACKINGS -name "*.mlir" | sort); do
  FNAME=$(basename $i)
  echo -e " Compiling (google benchmark) $FNAME"

  $COMPILE_BENCHMARK -D$DATASET_SIZE -M MLIR -B ${BENCHMARK_NAME%-*} $i $OUTPUT_PACKINGS_EXE
  if [ $? -ne 0 ]; then
    echoRed "  (google benchmark) Error: $FNAME" | tee -a $OUTPUT_PACKINGS/error.txt
    continue
  fi
done
