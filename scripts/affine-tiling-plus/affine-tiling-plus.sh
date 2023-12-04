#!/bin/bash
# Tile mlir files with affine-loop-tile

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
   echo "Tile polybench kernels in mlir with the tiling pass in Affine"
   echo
   echo "Syntax: $(basename $0) INPUT_DIR OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-h: Print this Help."
   echo -e "\t-c [SIZE]: Specify cache size to be used by affine tiling in KiB. Default is 256."
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
  if [[ -z $MLIR_PLUS_OPT || ! -f $MLIR_PLUS_OPT ]]; then
    echo "mlir-plus-opt not found!"
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

cacheSize="256"

while getopts ":hvc:" option; do
  case $option in
    h)
      Help
      exit 0
      ;;
    c)
      cacheSize=${OPTARG}
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

for i in $(find $INPUT_DIR -name "*.mlir" | sort); do
  FNAME=$(basename $i)
  echo -e " Tiling (mlir-plus-opt) $FNAME"
  KERNEL_NAME=$(echo "kernel_${FNAME%.*}" | tr '-' '_')

  $MLIR_PLUS_OPT $i \
      -affine-loop-tile="cache-size=${cacheSize}" \
      -affine-loop-invariant-code-motion \
      -affine-loop-normalize \
      -canonicalize \
      -affine-simplify-structures \
      -cse \
      2> /dev/null > "$OUTPUT_DIR/${FNAME%.*}.mlir"
  if [ $? -ne 0 ]; then
    echoRed "  Error: $FNAME" | tee -a $OUTPUT_DIR/error.txt
    continue
  fi
done
