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

All experiments are launched through a single entry point: **`run_simulation.sh`**.

#### Simple Test (quick validation)

```bash
./run_simulation.sh simple
```

This submits both MPI and Python jobs for a small problem size:

| Parameter | Value |
|-----------|-------|
| Height    | 256   |
| Width     | 256   |
| Rings     | 1     |
| Nodes     | 1     |
| Ranks     | 2, 4, 8 |
| Trials    | 5     |

Total jobs: 3 rank values × 2 methods × 5 trials = **30 jobs**

Once all jobs complete, generate the comparison figure:

```bash
python3 analyze_timings.py --simple
```

This produces `simple.png` containing results for only the 256×256 configuration.

**Output location:** All results are written to `./output/` using the naming
convention:

```
output/height-{H}_width-{W}_numRings-{R}_numNodes-{N}_numRanks-{RK}/
```

For the simple test this creates:

```
output/height-256_width-256_numRings-1_numNodes-1_numRanks-2/
output/height-256_width-256_numRings-1_numNodes-1_numRanks-4/
output/height-256_width-256_numRings-1_numNodes-1_numRanks-8/
```

Each directory contains:

| File pattern | Description |
|---|---|
| `gen_mpi_time_trial_{T}.txt` | MPI generation wall-clock time for trial T |
| `gen_py_time_trial_{T}.txt` | Python generation elapsed time for trial T |
| `gen_mpi_{H}_{W}_{R}_{N}_{RK}_trial_{T}.out/.err` | MPI job stdout/stderr |
| `gen_py_{H}_{W}_{R}_{N}_{RK}_trial_{T}.out/.err` | Python job stdout/stderr |

#### Complex Test (full parameter sweep)

```bash
./run_simulation.sh complex
```

This submits the full parameter sweep:

| Parameter | Values |
|-----------|--------|
| Heights   | 4096, 16384, 65536 |
| Widths    | 256, 1024, 4096 |
| Node×Rank pairs | (4,4), (8,8), (16,16) |
| Rings     | 1 |
| Trials    | 5 |

Total: 27 configurations × 5 trials × 2 methods = **270 jobs**

Once all jobs complete, generate the comparison figure:

```bash
python3 analyze_timings.py --complex
```

This produces `complex.png` containing results for the full parameter sweep.

#### Run Both

```bash
./run_simulation.sh all
```

Submits simple followed by complex tests.

#### Individual Submission Scripts

For ad-hoc runs you can still call the submission scripts directly:

```bash
# MPI-based generation (with SST)
./submit_generate_mpi.sh <height> <width> <numRings> <numNodes> <numRanks> <trials>

# Python-based generation (without SST)
./submit_generate_python.sh <height> <width> <numRings> <numNodes> <numRanks> <trials>
```

### 5. Analyze Results

After experiments complete, generate comparison figures. One of `--simple` or
`--complex` must be specified:

```bash
# Analyze simple results (256×256) → simple.png
python3 analyze_timings.py --simple

# Analyze complex results (full parameter sweep) → complex.png
python3 analyze_timings.py --complex
```

## Results Analysis

### Key Findings

Based on experiments across 27 configurations with 5 trials each:

1. **Pure Python consistently outperforms MPI-based generation**: Across all tested configurations, the Python approach (without SST) achieved faster JSON generation times than the MPI-based approach (with SST).
2. **Lower variance with Python**: The Python method shows significantly lower standard deviation in timing results. This may have been caused by system resources. May prove better on other HPC systems.
3. **Scaling behavior**: Both methods benefit from increased parallelism, but Python maintains a consistent advantage. This is due to it avoiding SST initialization overhead. 

### Reference Results

Expected/reference results from the original experiments are stored in:

- **`simple_groundtruth.txt`** — Ground-truth timing data for the simple (256×256) configuration
- **`complex_groundtruth.txt`** — Ground-truth timing data for the complex (full parameter sweep) configuration

> **Note:** `complex_groundtruth.txt` supersedes the former `original_results.png`.

## Directory Structure

```
ahp-json-writing/
├── Containerfile                  # Container build definition
├── README.md                      # This file
├── run_simulation.sh              # Main entry point (simple / complex / all)
├── analyze_timings.py             # Results analysis and plotting
├── simple_groundtruth.txt         # Reference results for simple (256×256) test
├── complex_groundtruth.txt        # Reference results for complex (full sweep) test
├── container-to-sif.sh            # Podman to Apptainer converter
├── run_generate_python_trial.sh   # Wrapper script for Python generation
├── submit_generate_mpi.sh         # Submit MPI generation jobs
├── submit_generate_python.sh      # Submit Python generation jobs
└── output/                        # Experiment output directory (created at runtime)
```

## File Descriptions

| File | Description |
|------|-------------|
| `run_simulation.sh` | **Main entry point** — run `simple`, `complex`, or `all` experiments |
| `Containerfile` | Builds container with SST, ahp_graph, and PHOLD benchmarks |
| `submit_generate_mpi.sh` | Submits Slurm jobs for MPI-based JSON generation |
| `submit_generate_python.sh` | Submits Slurm jobs for pure Python JSON generation |
| `run_generate_python_trial.sh` | Wrapper script executed by Python jobs to run and time generation |
| `analyze_timings.py` | Parses output files, removes outliers, and generates comparison plots (`--simple` or `--complex`) |
| `container-to-sif.sh` | Converts Podman images to Apptainer SIF format |

## Output Format

Experiments create outputs in `output/height-{h}_width-{w}_numRings-{r}_numNodes-{n}_numRanks-{rk}/`:
- `gen_mpi_time_trial_*.txt` - MPI generation timing
- `gen_py_time_trial_*.txt` - Python generation timing
- `*.out`, `*.err` - Job stdout/stderr logs

## License

See the repository's [LICENSE](../LICENSE) file.
