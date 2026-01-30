#!/usr/bin/env bash

# Usage: ./submit_generate_mpi.sh height width numRings numNodes numRanks trials

set -euo pipefail

height=$1
width=$2
numRings=$3
numNodes=$4
numRanks=$5
trials=${6:-1}

prefix="{ time e4s-cl -q launch --image ahp-json-writing.sif srun -N ${numNodes} --ntasks-per-node=${numRanks} -- "

output_dir="output/height-${height}_width-${width}_numRings-${numRings}_numNodes-${numNodes}_numRanks-${numRanks}"

# Create the output directory
mkdir -p ${output_dir}

for trial in $(seq 0 $((trials-1))); do
    jobname="gen_mpi_${height}_${width}_${numRings}_${numNodes}_${numRanks}_trial_${trial}"
    
    echo "Submitting ${jobname}"
    
    sbatch --job-name="${jobname}" \
           -N ${numNodes} \
           --ntasks-per-node=${numRanks} \
           --output="${output_dir}/${jobname}.out" \
           --error="${output_dir}/${jobname}.err" \
           --wrap "${prefix} sst --parallel-load=SINGLE /workspace/sst-benchmarks/phold/phold_dist_ahp.py -- --height ${height} --width ${width} --numRings ${numRings} --numNodes ${numNodes} --numRanks ${numRanks} --trial ${trial} --write ; } 2> ${output_dir}/gen_mpi_time_trial_${trial}.txt"
done