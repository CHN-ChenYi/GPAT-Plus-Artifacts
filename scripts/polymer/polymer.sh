#!/bin/bash
# Transform mlir files with polymer

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
   echo "Optimize polybench kernels in mlir with Polymer (Pluto)"
   echo
   echo "Syntax: $(basename $0) INPUT_DIR OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-h: Print this Help."
   echo -e "\t-v: Verbose mode."
   echo
   echo "To change Pluto's default tiling size (32 in every loop),"
   echo "add a file named 'tile.sizes' in the output dir, with a tiling factor in each line"
   echo "more info in https://github.com/bondhugula/pluto/blob/b2aef10f7134f8876de7455e3d598e72e946afb0/doc/DOC.txt#L164"
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

  if [[ -z $POLYMER_OPT || ! -f $POLYMER_OPT ]]; then
    echo "polymer-opt not found!"
    exit 1
  fi

  if [[ -z $POLYMER_PLUTO_LIB || ! -d $POLYMER_PLUTO_LIB ]]; then
    echo "Pluto lib not found!"
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

while getopts ":hv" option; do
  case $option in
    h)
      Help
      exit 0
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

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${POLYMER_PLUTO_LIB}"

cd $OUTPUT_DIR

for i in $(find $INPUT_DIR -name "*.mlir" | sort); do
  FNAME=$(basename $i)
  echo -e " Polymer (polymer-opt) $FNAME"
  KERNEL_NAME=$(echo "kernel_${FNAME%.*}" | tr '-' '_')

  if [[ "${FNAME%.*}" == "symm" ||
        "${FNAME%.*}" == "ludcmp" ||
        "${FNAME%.*}" == "nussinov" ]]; then
    echoYellow "  Skipping: fails with Polymer"
    echoRed "  Error: $FNAME" >> $OUTPUT_DIR/error.txt
    continue
  fi

  if [[ "${FNAME%.*}" == "adi" ||
        "${FNAME%.*}" == "deriche" ]]; then
    echoYellow "  Skipping: timesout in 20s with Polymer"
    echoRed "  Timeout: $FNAME" >> $OUTPUT_DIR/error.txt
    continue
  fi

  # Allow unregistered dialect required so it does not complain about
  # the data layout attributes
  timeout 20s $POLYMER_OPT $i \
      -allow-unregistered-dialect \
      -insert-redundant-load \
      -extract-scop-stmt \
      -canonicalize \
      -pluto-opt \
      -inline \
      -canonicalize 2> /dev/null > "$OUTPUT_DIR/${FNAME%.*}.tmp.mlir"

  out_code=$?
  if [ $out_code -eq 124 ]; then
    echoRed "  (polymer-opt) Timeout: $FNAME" | tee -a $OUTPUT_DIR/error.txt
    continue
  fi
  if [ $out_code -ne 0 ]; then
    echoRed "  (polymer-opt) Error: $FNAME" | tee -a $OUTPUT_DIR/error.txt
    continue
  fi

  $MLIR_OPT \
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
