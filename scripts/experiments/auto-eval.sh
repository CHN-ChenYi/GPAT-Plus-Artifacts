#!/bin/bash
# Executes experimental workflow exactly as used in the paper

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

function CheckPerfParanoid()
{
  paranoid=$(cat '/proc/sys/kernel/perf_event_paranoid')
  if [ "$paranoid" -gt "1" ]; then
    echo "Please set kernel event paranoid to a least 1 to be able to use perf"
    echo "Use the following command:"
    echo "    sudo sh -c 'echo 1 > /proc/sys/kernel/perf_event_paranoid'"
    exit 1
  fi
}

function Help()
{
   echo "Executes experimental workflow exactly as used in the paper"
   echo
   echo "Syntax: $(basename $0) OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-D [SIZE]: Specify size of dataset: MINI, SMALL, MEDUIM, LARGE, EXTRALARGE"
   echo -e "\t-h: Print this Help."
   echo -e "\t-v: Verbose mode."
   echo
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

CheckPerfParanoid

scriptPath=$(getScriptLocation)

GEN_FILES_SH="$scriptPath/polybench-evaluation/generate-files.sh"
RUN_SH="$scriptPath/polybench-evaluation/run.sh"
PARSE_PY="$scriptPath/polybench-evaluation/parse-log.py"

EVAL_OUTPUT="$OUTPUT_DIR/polybench-affine-tiling-LARGE"
mkdir ${EVAL_OUTPUT}
mkdir ${EVAL_OUTPUT}/logs
mkdir ${EVAL_OUTPUT}/graphs
$GEN_FILES_SH -D LARGE -T AffineTiling ${EVAL_OUTPUT}
$RUN_SH -r 100 -p -D LARGE ${EVAL_OUTPUT} ${EVAL_OUTPUT}/logs
$PARSE_PY ${EVAL_OUTPUT}/logs ${EVAL_OUTPUT}/graphs AffineTiling

EVAL_OUTPUT="$OUTPUT_DIR/polybench-polymer-LARGE"
mkdir ${EVAL_OUTPUT}
mkdir ${EVAL_OUTPUT}/logs
mkdir ${EVAL_OUTPUT}/graphs
$GEN_FILES_SH -D LARGE -T Polymer ${EVAL_OUTPUT}
$RUN_SH -r 100 -p -D LARGE ${EVAL_OUTPUT} ${EVAL_OUTPUT}/logs
$PARSE_PY ${EVAL_OUTPUT}/logs ${EVAL_OUTPUT}/graphs Polymer

GEN_FILES_SH="$scriptPath/packing-selection-evaluation/generate-files.sh"
RUN_SH="$scriptPath/packing-selection-evaluation/run.sh"
PARSE_PY="$scriptPath/packing-selection-evaluation/parse-log.py"

EVAL_OUTPUT="$OUTPUT_DIR/packing-selection-gemm-LARGE"
mkdir ${EVAL_OUTPUT}
mkdir ${EVAL_OUTPUT}/graphs
$GEN_FILES_SH -D LARGE -B gemm ${EVAL_OUTPUT}
$RUN_SH -r 100 -p -D LARGE ${EVAL_OUTPUT}/executables ${EVAL_OUTPUT}
$PARSE_PY ${EVAL_OUTPUT}/output.log ${EVAL_OUTPUT}/graphs gemm

EVAL_OUTPUT="$OUTPUT_DIR/packing-selection-gemm-BLIS-LARGE"
mkdir ${EVAL_OUTPUT}
mkdir ${EVAL_OUTPUT}/graphs
$GEN_FILES_SH -D LARGE -B gemm-blis ${EVAL_OUTPUT}
$RUN_SH -r 100 -p -D LARGE ${EVAL_OUTPUT}/executables ${EVAL_OUTPUT}
$PARSE_PY ${EVAL_OUTPUT}/output.log ${EVAL_OUTPUT}/graphs gemm-blis

EVAL_OUTPUT="$OUTPUT_DIR/packing-selection-2mm-LARGE"
mkdir ${EVAL_OUTPUT}
mkdir ${EVAL_OUTPUT}/graphs
$GEN_FILES_SH -D LARGE -B 2mm ${EVAL_OUTPUT}
$RUN_SH -r 100 -p -D LARGE ${EVAL_OUTPUT}/executables ${EVAL_OUTPUT}
$PARSE_PY ${EVAL_OUTPUT}/output.log ${EVAL_OUTPUT}/graphs 2mm