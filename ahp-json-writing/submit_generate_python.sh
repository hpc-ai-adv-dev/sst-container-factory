#!/usr/bin/env bash

# Usage: ./submit_generate_python.sh height width numRings numNodes numRanks trials

set -euo pipefail

# ENV_SCRIPT="./setSSTEnvironment.sh"

height=$1
width=$2
numRings=$3
numNodes=$4
numRanks=$5
trials=${6:-1}

output_dir="output/height-${height}_width-${width}_numRings-${numRings}_numNodes-${numNodes}_numRanks-${numRanks}"

# Create the output directory
mkdir -p ${output_dir}

for trial in $(seq 0 $((trials-1))); do
    jobname="gen_py_${height}_${width}_${numRings}_${numNodes}_${numRanks}_trial_${trial}"
    
    echo "Submitting ${jobname}"
    
    sbatch --job-name="${jobname}" \
           -N ${numNodes} \
           --ntasks-per-node=${numRanks} \
           --output="${output_dir}/${jobname}.out" \
           --error="${output_dir}/${jobname}.err" \
           ./run_generate_python_trial.sh ${height} ${width} ${numRings} ${numNodes} ${numRanks} ${trial} ${output_dir}
done