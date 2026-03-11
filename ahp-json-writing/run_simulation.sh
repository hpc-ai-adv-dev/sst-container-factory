#!/usr/bin/env bash
# ==============================================================================
# run_simulation.sh - Unified experiment runner for PHOLD JSON writing benchmarks
# ==============================================================================
#
# Usage:
#   ./run_simulation.sh simple    Run a quick validation test
#   ./run_simulation.sh complex   Run the full parameter sweep
#   ./run_simulation.sh all       Run both simple and complex tests
#
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 {simple|complex|all}

Modes:
  simple   Quick validation test
             height=256, width=256, rings=1, nodes=1, ranks=[2,4,8], 5 trials
             Automatically submits an analysis job to generate simple.png

  complex  Full parameter sweep
             heights=[4096,16384,65536], widths=[256,1024,4096]
             node×rank pairs=[(4,4),(8,8),(16,16)], rings=1, 5 trials
             27 configurations × 5 trials × 2 methods = 270 jobs

  all      Run both simple and complex tests sequentially
EOF
    exit 1
}

# ===========================================================================
# SIMPLE TEST
# ===========================================================================
run_simple() {
    local height=256
    local width=256
    local numRings=1
    local numNodes=1
    local ranks=(2 4 8)
    local trials=5

    echo "============================================================"
    echo " SIMPLE Test Configuration"
    echo "============================================================"
    echo ""
    echo "Parameters:"
    echo "  Height:  ${height}"
    echo "  Width:   ${width}"
    echo "  Rings:   ${numRings}"
    echo "  Nodes:   ${numNodes}"
    echo "  Ranks:   ${ranks[*]}"
    echo "  Trials:  ${trials}"
    echo ""
    echo "Output Location: ./output/"
    echo ""
    echo "  Directory naming convention:"
    echo "    output/height-{H}_width-{W}_numRings-{R}_numNodes-{N}_numRanks-{RK}/"
    echo ""
    echo "  For this simple test, the following directories will be created:"
    for r in "${ranks[@]}"; do
        echo "    output/height-${height}_width-${width}_numRings-${numRings}_numNodes-${numNodes}_numRanks-${r}/"
    done
    echo ""
    echo "  Files within each directory:"
    echo "    gen_mpi_time_trial_{T}.txt                          - MPI wall-clock time for trial T"
    echo "    gen_py_time_trial_{T}.txt                           - Python elapsed time for trial T"
    echo "    gen_mpi_{H}_{W}_{R}_{N}_{RK}_trial_{T}.out/.err     - MPI job stdout/stderr"
    echo "    gen_py_{H}_{W}_{R}_{N}_{RK}_trial_{T}.out/.err      - Python job stdout/stderr"
    echo ""
    echo "============================================================"
    echo ""

    for numRanks_val in "${ranks[@]}"; do
        echo "--- Submitting MPI jobs: ranks=${numRanks_val} ---"
        ./submit_generate_mpi.sh "${height}" "${width}" "${numRings}" "${numNodes}" "${numRanks_val}" "${trials}"

        echo "--- Submitting Python jobs: ranks=${numRanks_val} ---"
        ./submit_generate_python.sh "${height}" "${width}" "${numRings}" "${numNodes}" "${numRanks_val}" "${trials}"

        echo ""
    done

    echo "============================================================"
    echo " Simple test: all jobs submitted"
    echo "============================================================"
    echo ""
    echo "Once all jobs complete, generate the figure with:"
    echo "  python3 analyze_timings.py --simple"
    echo ""
    echo "This will produce: simple.png"
}

# ===========================================================================
# COMPLEX TEST (full parameter sweep)
# ===========================================================================
run_complex() {
    local trials=5
    local heights=(4096 16384 65536)
    local widths=(256 1024 4096)
    local node_rank_pairs=("4 4" "8 8" "16 16")
    local numRings=1

    echo "============================================================"
    echo " COMPLEX Test Configuration (Full Parameter Sweep)"
    echo "============================================================"
    echo ""
    echo "Parameters:"
    echo "  Heights:          ${heights[*]}"
    echo "  Widths:           ${widths[*]}"
    echo "  Node×Rank pairs:  (4,4), (8,8), (16,16)"
    echo "  Rings:            ${numRings}"
    echo "  Trials:           ${trials}"
    echo "  Total configs:    27  (3 heights × 3 widths × 3 node/rank pairs)"
    echo "  Total jobs:       270 (27 configs × 5 trials × 2 methods)"
    echo ""
    echo "============================================================"
    echo ""

    local total=0

    echo "--- Submitting MPI experiments ---"
    for height in "${heights[@]}"; do
        for width in "${widths[@]}"; do
            for pair in "${node_rank_pairs[@]}"; do
                read -r numNodes numRanks <<< "$pair"
                echo "MPI: height=${height} width=${width} rings=${numRings} nodes=${numNodes} ranks=${numRanks}"
                ./submit_generate_mpi.sh "${height}" "${width}" "${numRings}" "${numNodes}" "${numRanks}" "${trials}"
                ((++total))
            done
        done
    done

    echo ""
    echo "--- Submitting Python experiments ---"
    for height in "${heights[@]}"; do
        for width in "${widths[@]}"; do
            for pair in "${node_rank_pairs[@]}"; do
                read -r numNodes numRanks <<< "$pair"
                echo "Python: height=${height} width=${width} rings=${numRings} nodes=${numNodes} ranks=${numRanks}"
                ./submit_generate_python.sh "${height}" "${width}" "${numRings}" "${numNodes}" "${numRanks}" "${trials}"
                ((++total))
            done
        done
    done

    echo ""
    echo "============================================================"
    echo " Complex test: ${total} configurations submitted (${trials} trials each)"
    echo "============================================================"
    echo ""
    echo "Once all jobs complete, generate the figure with:"
    echo "  python3 analyze_timings.py --complex"
    echo ""
    echo "This will produce: complex.png"
}

# ===========================================================================
# Main
# ===========================================================================
if [[ $# -lt 1 ]]; then
    usage
fi

case "$1" in
    simple)
        run_simple
        ;;
    complex)
        run_complex
        ;;
    all)
        run_simple
        echo ""
        echo ""
        run_complex
        ;;
    *)
        usage
        ;;
esac
