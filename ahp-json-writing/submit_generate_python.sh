#!/usr/bin/env bash

# Usage: ./submit_generate_python.sh height width numRings numNodes numRanks trials

set -euo pipefail

ENV_SCRIPT="./setSSTEnvironment.sh"

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
    
    # Create a wrapper script to track overall execution time
    wrapper_script="${output_dir}/gen_py_trial_${trial}.sh"
    cat > "${wrapper_script}" << WRAPPER_EOF
#!/bin/bash
# Source environment for e4s-cl configuration
source ${ENV_SCRIPT} container

# Record start time
start_time=\$(date +%s%N)

# Run all ranks in parallel across nodes using srun
e4s-cl -q launch --image ahp-json-writing.sif srun --ntasks=\$((${numNodes} * ${numRanks})) -- \
     bash -c 'python3 /workspace/sst-benchmarks/phold/phold_dist_ahp.py --height ${height} --width ${width} --numRings ${numRings} --write --numNodes ${numNodes} --numRanks ${numRanks} --rank \${SLURM_PROCID}'

# Record end time
end_time=\$(date +%s%N)

# Calculate elapsed time in seconds
elapsed=\$((end_time - start_time))
elapsed_seconds=\$(echo "\$elapsed" | awk '{printf "%.3f", \$1 / 1000000000}')
echo "Elapsed time (s): \$elapsed_seconds" > "${output_dir}/gen_py_trial_${trial}_elapsed.txt"
WRAPPER_EOF
    chmod +x "${wrapper_script}"
    
    sbatch --job-name="${jobname}" \
           -N ${numNodes} \
           --ntasks-per-node=${numRanks} \
           --output="${output_dir}/${jobname}.out" \
           --error="${output_dir}/${jobname}.err" \
           --wrap "bash ${wrapper_script}"
done