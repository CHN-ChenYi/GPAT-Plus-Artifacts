#!/bin/bash
# Optimize mlir files with packing

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
   echo "Apply packing using GPAT's packing to polybench kernels in mlir"
   echo
   echo "Syntax: $(basename $0) INPUT_DIR OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-h: Print this Help."
   echo -e "\t-v: Verbose mode."
   echo -e "\t--l1 [SIZE]: Specify L1 cache size in KiB. Default is 32."
   echo -e "\t--l2 [SIZE]: Specify L2 cache size in KiB. Default is 256."
   echo -e "\t--l3 [SIZE]: Specify L3 cache size in KiB. Default is 8192."
   echo -e "\t--cache-line [SIZE]: Specify cache line size in Bytes. Default is 64."
   echo -e "\t--dtlb-entries [NUMBER]: Specify number of TLB entries in the L1 DTLB. Default is 64."
   echo -e "\t--dtlb-page [SIZE]: Specify page size in KiB. Default is 4."
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
  if [[ -z $MLIR_PLUS_OPT || ! -f $MLIR_PLUS_OPT ]]; then
    echo "mlir-opt not found!"
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

L1=""
L2=""
L3=""
CACHE_LINE=""
DTLB_ENTRY=""
DTLB_PAGE=""

PARSED_ARGUMENTS=$(getopt -a -n "mlir-packing" -o hv --long l1:,l2:,l3:,cache-line:,dtlb-entries:,dtlb-page-size:, -- "$@")
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
    --l1)
      L1="$2"
      shift 2
      ;;
    --l2)
      L2="$2"
      shift 2
      ;;
    --l3)
      L3="$2"
      shift 2
      ;;
    --cache-line)
      CACHE_LINE="$2"
      shift 2
      ;;
    --dtlb-entries)
      DTLB_ENTRY="$2"
      shift 2
      ;;
    --dtlb-page-size)
      DTLB_PAGE="$2"
      shift 2
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

# Source config and check dependencies
sourceConfigFile
checkDependencies

cd $OUTPUT_DIR
mkdir -p logs

FLAGS=""

if [[ ! -z $L1 ]]; then
  FLAGS="$FLAGS l1-cache-size=$L1"
fi

if [[ ! -z $L2 ]]; then
  FLAGS="$FLAGS l2-cache-size=$L2"
fi

if [[ ! -z $L3 ]]; then
  FLAGS="$FLAGS l3-cache-size=$L3"
fi

if [[ ! -z $CACHE_LINE ]]; then
  FLAGS="$FLAGS cache-line-size=$CACHE_LINE"
fi

if [[ ! -z $DTLB_ENTRY ]]; then
  FLAGS="$FLAGS l1d-tlb-entries=$DTLB_ENTRY"
fi

if [[ ! -z $DTLB_PAGE ]]; then
  FLAGS="$FLAGS l1d-tlb-page-size=$DTLB_PAGE"
fi

for i in $(find $INPUT_DIR -name "*.mlir" | sort); do
  FNAME=$(basename $i)
  echo -e " Packing (mlir-plus-opt) $FNAME"
  KERNEL_NAME=$(echo "kernel_${FNAME%.*}" | tr '-' '_')

  $MLIR_PLUS_OPT $i \
    -affine-loop-invariant-code-motion \
    -affine-loop-pack="$FLAGS" \
    -debug-only="affine-loop-pack" \
    -affine-loop-normalize \
    -canonicalize \
    -affine-simplify-structures \
    -cse \
    > "$OUTPUT_DIR/${FNAME%.*}.mlir" 2> "logs/${FNAME%.*}.log"
  if [ $? -ne 0 ]; then
    echoRed "  Error: $FNAME" | tee -a $OUTPUT_DIR/error.txt
    continue
  fi
done
