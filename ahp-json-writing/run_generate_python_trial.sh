#!/usr/bin/env bash
# Persistent wrapper script for Python JSON generation
# Usage: run_generate_python_trial.sh <height> <width> <numRings> <numNodes> <numRanks> <trial> <output_dir>

set -euo pipefail

height=$1
width=$2
numRings=$3
numNodes=$4
numRanks=$5
trial=$6
output_dir=$7

# ENV_SCRIPT="./setSSTEnvironment.sh"

# # Source environment for e4s-cl configuration
# source ${ENV_SCRIPT}

# Record start time
start_time=$(date +%s%N)

# Run all ranks in parallel across nodes using srun
# e4s-cl launch --image ahp-json-writing.sif srun --ntasks=$((${numNodes} * ${numRanks})) -- "python3 --version && which python3"
e4s-cl -q launch --image ahp-json-writing.sif srun --ntasks=$((${numNodes} * ${numRanks})) -- \
     "python3 /workspace/sst-benchmarks/phold/phold_dist_ahp.py --height ${height} --width ${width} --numRings ${numRings} --write --numNodes ${numNodes} --numRanks ${numRanks} --trial ${trial} --rank \${SLURM_PROCID}"
     # bash -c "python3 /workspace/sst-benchmarks/phold/phold_dist_ahp.py --height ${height} --width ${width} --numRings ${numRings} --draw --write --build --numNodes ${numNodes} --numRanks ${numRanks} --rank 1"

# Record end time
end_time=$(date +%s%N)

# Calculate elapsed time in seconds
elapsed=$((end_time - start_time))
elapsed_seconds=$(echo "$elapsed" | awk '{printf "%.3f", $1 / 1000000000}')
echo "Elapsed time (s): $elapsed_seconds" > "${output_dir}/gen_py_time_trial_${trial}.txt"
