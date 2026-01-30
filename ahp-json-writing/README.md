# AHP JSON Writing Experiments

This directory contains the infrastructure for running PHOLD benchmark experiments that compare JSON generation times with and without SST (Structural Simulation Toolkit).

## Overview

These experiments evaluate the performance of JSON file generation for distributed PHOLD simulations using:
- **With SST**: MPI-based distributed generation using SST's runtime
- **Without SST**: Pure Python parallel generation

## Prerequisites

- [Podman](https://podman.io/) (for building containers)
- [Apptainer](https://apptainer.org/) (for running SIF containers on HPC systems)
- Slurm job scheduler
- e4s-cl (E4S Container Launcher)

## Quick Start

### 1. Clone the Repository

```bash
git clone git@github.com:hpc-ai-adv-dev/sst-container-factory.git
cd sst-container-factory/ahp-json-writing
```

### 2. Build the Container

```bash
podman build -f Containerfile -t ahp-json-writing:latest .
```

### 3. Convert to SIF Format

Convert the Podman image to Apptainer SIF format for HPC use:

```bash
./container-to-sif.sh localhost/ahp-json-writing:latest -f ahp-json-writing
```

This creates `ahp-json-writing.sif` in the current directory.

### 4. Run Experiments

#### Single Experiment

**MPI-based generation (with SST):**
```bash
./submit_generate_mpi.sh <height> <width> <numRings> <numNodes> <numRanks> <trials> <mode>
```

**Python-based generation (without SST):**
```bash
./submit_generate_python.sh <height> <width> <numRings> <numNodes> <numRanks> <trials>
```

Example:
```bash
./submit_generate_mpi.sh 16 16 1 2 2 5
./submit_generate_python.sh 16 16 1 2 2 5
```

#### Full Parameter Sweep

Source the experiment configuration file and run all experiments:

```bash
source json_workflow_experiments.txt

# Run MPI experiments (5 trials)
submit_all_mpi_experiments 5

# Run Python experiments (5 trials)
submit_all_python_experiments 5
```

**Parameter sweep configurations:**
- Heights: 4096, 16384, 65536
- Widths: 256, 1024, 4096
- Node×Rank pairs: (4,4), (8,8), (16,16)
- Total: 27 configurations × 5 trials = 135 jobs per function

### 6. Analyze Results

After experiments complete, analyze the timing data.

```bash
apptainer exec ahp-json-writing.sif python3 /workspace/analyze_timings.py
```

Or run with bind mounting (if actively modifying the file):
```bash
apptainer exec --bind ./analyze_timings.py:/workspace/analyze_timings.py ahp-json-writing.sif python3 /workspace/analyze_timings.py
```

This generates `generation_timings_combined.png` showing timing comparisons.

## Results Analysis

### Key Findings

Based on experiments across 27 configurations with 5 trials each:

1. **Pure Python consistently outperforms MPI-based generation**: Across all tested configurations, the Python approach (without SST) achieved faster JSON generation times than the MPI-based approach (with SST).
2. **Lower variance with Python**: The Python method shows significantly lower standard deviation in timing results. This may have been caused by system resources. May prove better on other HPC systems.
3. **Scaling behavior**: Both methods benefit from increased parallelism, but Python maintains a consistent advantage. This is due to it avoiding SST initialization overhead. 

### Reference Results

The expected/reference results from the original experiments are stored in:

**`original_results.png`**

## Directory Structure

```
ahp-json-writing/
├── Containerfile                  # Container build definition
├── README.md                      # This file
├── analyze_timings.py             # Results analysis and plotting
├── container-to-sif.sh            # Podman to Apptainer converter
├── json_workflow_experiments.txt  # Parameter sweep configuration
├── original_results.png           # Reference results from experiments
├── run_generate_python_trial.sh   # Wrapper script for Python generation
├── submit_generate_mpi.sh         # Submit MPI generation jobs
├── submit_generate_python.sh      # Submit Python generation jobs
└── output/                        # Experiment output directory (created at runtime)
```

## File Descriptions

| File | Description |
|------|-------------|
| `Containerfile` | Builds container with SST, ahp_graph, and PHOLD benchmarks |
| `submit_generate_mpi.sh` | Submits Slurm jobs for MPI-based JSON generation |
| `submit_generate_python.sh` | Submits Slurm jobs for pure Python JSON generation |
| `run_generate_python_trial.sh` | Wrapper script executed by Python jobs to run and time generation |
| `json_workflow_experiments.txt` | Defines parameter sweep functions for experiments |
| `analyze_timings.py` | Parses output files, removes outliers, and generates comparison plots |
| `container-to-sif.sh` | Converts Podman images to Apptainer SIF format |

## Output Format

Experiments create outputs in `output/height-{h}_width-{w}_numRings-{r}_numNodes-{n}_numRanks-{rk}/`:
- `gen_mpi_time_trial_*.txt` - MPI generation timing
- `gen_py_time_trial_*.txt` - Python generation timing
- `*.out`, `*.err` - Job stdout/stderr logs

## License

See the repository's [LICENSE](../LICENSE) file.
