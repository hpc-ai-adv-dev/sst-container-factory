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

### 4. Configure Your Environment

Edit `setSSTEnvironment.sh` to match your HPC system's module and environment setup. This script is sourced before running experiments.

### 5. Run Experiments

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
./submit_generate_mpi.sh 16 16 1 2 2 5 container
./submit_generate_python.sh 16 16 1 2 2 5
```

#### Full Parameter Sweep

Source the experiment configuration file and run all experiments:

```bash
source json_workflow_experiments.txt

# Run MPI experiments (5 trials, container mode)
submit_all_mpi_experiments 5 container

# Run Python experiments (5 trials)
submit_all_python_experiments 5
```

**Parameter sweep configurations:**
- Heights: 4096, 16384, 65536
- Widths: 256, 1024, 4096
- Node×Rank pairs: (4,4), (8,8), (16,16)
- Total: 27 configurations × 5 trials = 135 jobs per function

### 6. Analyze Results

After experiments complete, analyze the timing data:

```bash
python3 analyze_timings.py
```

Or run inside the container:
```bash
apptainer exec ahp-json-writing.sif python3 /workspace/analyze_timings.py
```

This generates `generation_timings_combined.png` showing timing comparisons.

## Ground Truth Results

The expected/reference results from the original experiments are stored in:

**`original_results.png`**

## Directory Structure

```
ahp-json-writing/
├── Containerfile              # Container build definition
├── README.md                  # This file
├── analyze_timings.py         # Results analysis and plotting
├── container-to-sif.sh        # Podman to Apptainer converter
├── json_workflow_experiments.txt  # Parameter sweep configuration
├── original_results.png       # Ground truth results
├── setSSTEnvironment.sh       # Environment setup (customize for your system)
├── submit_generate_mpi.sh     # Submit MPI generation jobs
├── submit_generate_python.sh  # Submit Python generation jobs
└── output/                    # Experiment output directory (created at runtime)
```

## File Descriptions

| File | Description |
|------|-------------|
| `Containerfile` | Builds container with SST, ahp_graph, and PHOLD benchmarks |
| `submit_generate_mpi.sh` | Submits Slurm jobs for MPI-based JSON generation |
| `submit_generate_python.sh` | Submits Slurm jobs for pure Python JSON generation |
| `json_workflow_experiments.txt` | Defines parameter sweep functions for experiments |
| `analyze_timings.py` | Parses output files and generates comparison plots |
| `container-to-sif.sh` | Converts Podman images to Apptainer SIF format |
| `setSSTEnvironment.sh` | System-specific environment configuration |

## Output Format

Experiments create outputs in `output/height-{h}_width-{w}_numRings-{r}_numNodes-{n}_numRanks-{rk}/`:
- `gen_mpi_time_trial_*.txt` - MPI generation timing
- `gen_py_trial_*_elapsed.txt` - Python generation timing
- `sim_*_timing_trial_*.json` - Simulation timing data
- `*.out`, `*.err` - Job stdout/stderr logs

## License

See the repository's [LICENSE](../LICENSE) file.
