#!/bin/bash
# Run multiple executables with perf and output a log file in the output dir

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
   echo "Run multiple executables to output a log file in the output dir"
   echo
   echo "Syntax: $(basename $0) -D DATASET_SIZE INPUT_DIR OUTPUT_DIR"
   echo "Options:"
   echo -e "\t-D [SIZE]: Specify size of dataset: MINI, SMALL, MEDUIM, LARGE, EXTRALARGE"
   echo -e "\t-h: Print this Help."
   echo -e "\t-p: Collect perf event counters."
   echo -e "\t-v: Verbose mode."
   echo -e "\t-r [NUMBER]: Specify repetition number (overrides defaults)."
   echo
   echo -e "Repetition number of executions by default are:"
   echo -e "\tMINI:       5000"
   echo -e "\tSMALL:      2000"
   echo -e "\tMEDIUM:     500"
   echo -e "\tLARGE:      25"
   echo -e "\tEXTRALARGE: 5"
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
  if [[ -z $CORES ]]; then
    echo "Number of logical processors not defined"
    exit 1
  fi
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
collect_perf="false"
CUSTOM_REPEATS=""

while getopts ":hvpD:r:" option; do
  case $option in
    h)
      Help
      exit 0
      ;;
    v)
      set -x
      ;;
    p)
      collect_perf="true"
      ;;
    D)
      DATASET_SIZE=${OPTARG}
     ;;
    r)
      CUSTOM_REPEATS=${OPTARG}
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

# Source spec
sourceSpecFile
checkSpecs

# Check if perf will work and source spec
if [[ "$collect_perf" == "true" ]]; then
  CheckPerfParanoid
fi

# Output log path
OUTPUT_LOG="$OUTPUT_DIR/output.log"
if [ -f $OUTPUT_LOG ]; then
    echo "ERROR: Output log already exists."
    echo "Please remove $OUTPUT_LOG"
    exit 1
fi

case $DATASET_SIZE in
  MINI)
    REPEATS=5000
   ;;
  SMALL)
    REPEATS=2000
   ;;
  MEDIUM)
    REPEATS=500
   ;;
  LARGE)
    REPEATS=25
   ;;
  EXTRALARGE)
    REPEATS=5
   ;;
  *)
    echo "Please specify tile size. Use MINI, SMALL, MEDIUM, LARGE, EXTRALARGE."
    Help
    exit 1
   ;;
esac

if [[ ! -z $CUSTOM_REPEATS ]]; then
  REPEATS=$CUSTOM_REPEATS
fi

for i in $(find $INPUT_DIR -name "*.exe" | sort); do
  FNAME=$(basename $i)
  echoGreen "\nRunning $FNAME"

  # seed random
  RANDOM=$(date +%s%N | cut -b10-19 | sed -e 's/^0*//;s/^$/0/')

  if [[ "$collect_perf" == "true" ]]; then
    perf stat -e '{cycles,instructions},{mem_load_retired.l1_miss,mem_load_retired.l2_miss,mem_load_retired.l3_miss},{dtlb_load_misses.stlb_hit,dtlb_load_misses.miss_causes_a_walk}' taskset --cpu-list $(( $RANDOM % $CORES )) $i --benchmark_repetitions=$REPEATS 2>&1 | tee -a $OUTPUT_LOG
  else
    taskset --cpu-list $(( $RANDOM % $CORES )) $i --benchmark_repetitions=$REPEATS 2>&1 | tee -a $OUTPUT_LOG
  fi

done
