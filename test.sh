#!/bin/bash
# Container Testing Workflow Script
# Provides common testing operations with simple commands

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

show_usage() {
    cat << EOF
Container Testing Workflow Script

Usage: $0 COMMAND [OPTIONS]

COMMANDS:
  test-all           Run comprehensive test suite
  test-core          Test core container build
  test-full          Test full container build
  test-dev           Test development container build
  test-custom        Test custom repository build (requires --repo and --ref)
  test-experiment    Test experiment container build (requires --experiment-name)
  validate IMAGE [TYPE]  Validate existing container image (TYPE: quick, full, no-exec)
  clean              Clean up all test artifacts and images
  download VERSION   Download source tarballs for specified version
  setup              Set up local testing environment
  benchmark          Run build performance benchmark
  help               Show this help message

OPTIONS:
  --version VERSION  SST version to use (default: 15.0.0)
  --mpich VERSION    MPICH version to use (default: 4.0.2)
  --repo URL         SST repository URL (for custom builds)
  --ref REF          SST repository reference (for custom builds)
  --experiment-name NAME  Experiment name (for experiment builds)
  --base-image IMAGE Base image (for experiment builds)
  --no-cache         Build without using cache
  --cleanup          Clean up after successful build
  --docker           Use docker container engine
  --podman           Use podman container engine

EXAMPLES:
  $0 test-core                          # Test SST-core build
  $0 test-full --version 15.1.0         # Test full build with specific version
  $0 test-custom --repo https://github.com/sstsimulator/sst-core.git --ref main
  $0 test-experiment --experiment-name phold-example
  $0 test-experiment --experiment-name tcl-test-experiment --base-image sst-core:latest
  $0 validate localhost:5000/sst-core:15.0.0-amd64        # Quick validation
  $0 validate localhost:5000/sst-full:15.0.0-amd64 full  # Full validation
  $0 validate localhost:5000/sst-dev:15.0.0-amd64 no-exec # No-exec validation
  $0 download 15.1.0                    # Download tarballs for SST 15.1.0
  $0 benchmark                          # Run performance benchmark
  $0 clean                              # Clean up everything

EOF
}

# Parse command line arguments (handle both orders: --option command and command --option)
VERSION="15.0.0"
MPICH_VERSION="4.0.2"
REPO=""
REF=""
EXPERIMENT_NAME=""
BASE_IMAGE=""
EXTRA_ARGS=()
CONTAINER_ENGINE_OVERRIDE=""
COMMAND=""

# First pass: collect all arguments
ALL_ARGS=("$@")

# Parse all arguments to find command and options
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --mpich)
            MPICH_VERSION="$2"
            shift 2
            ;;
        --repo)
            REPO="$2"
            shift 2
            ;;
        --ref)
            REF="$2"
            shift 2
            ;;
        --experiment-name)
            EXPERIMENT_NAME="$2"
            shift 2
            ;;
        --base-image)
            BASE_IMAGE="$2"
            shift 2
            ;;
        --docker)
            CONTAINER_ENGINE_OVERRIDE="docker"
            shift
            ;;
        --podman)
            CONTAINER_ENGINE_OVERRIDE="podman"
            shift
            ;;
        --no-cache|--cleanup)
            EXTRA_ARGS+=("$1")
            shift
            ;;
        help|--help|-h)
            show_usage
            exit 0
            ;;
        test-all|test-core|test-full|test-dev|test-custom|test-experiment|validate|clean|download|setup|benchmark)
            if [ -z "$COMMAND" ]; then
                COMMAND="$1"
            fi
            shift
            ;;
        *)
            # This might be a remaining argument for validate command
            REMAINING_ARGS+=("$1")
            shift
            ;;
    esac
done

# Capture remaining arguments for IMAGE in validate command
REMAINING_ARGS=("${ALL_ARGS[@]}")
# Filter out known options and command
FILTERED_REMAINING_ARGS=()
for arg in "${REMAINING_ARGS[@]}"; do
    case "$arg" in
        --version|--mpich|--repo|--ref|--experiment-name|--base-image|--docker|--podman|--no-cache|--cleanup|help|--help|-h|test-all|test-core|test-full|test-dev|test-custom|test-experiment|validate|clean|download|setup|benchmark)
            # Skip options and command
            ;;
        *)
            # Add to filtered remaining args
            FILTERED_REMAINING_ARGS+=("$arg")
            ;;
    esac
done
REMAINING_ARGS=("${FILTERED_REMAINING_ARGS[@]}")

if [ -z "$COMMAND" ]; then
    show_usage
    exit 1
fi

case "$COMMAND" in
    "test-all")
        echo "=== Running Comprehensive Test Suite ==="
        # Set environment for subprocess if engine was overridden
        ENV_PREFIX=""
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            ENV_PREFIX="CONTAINER_ENGINE=$CONTAINER_ENGINE_OVERRIDE"
        fi

        echo "Testing core build..."
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE" ./test-local-build.sh "${EXTRA_ARGS[@]}" --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" core
        else
            ./test-local-build.sh "${EXTRA_ARGS[@]}" --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" core
        fi

        echo "Testing full build..."
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE" ./test-local-build.sh "${EXTRA_ARGS[@]}" --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" full
        else
            ./test-local-build.sh "${EXTRA_ARGS[@]}" --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" full
        fi

        echo "Testing dev build..."
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE" ./test-local-build.sh "${EXTRA_ARGS[@]}" --mpich-version "$MPICH_VERSION" dev
        else
            ./test-local-build.sh "${EXTRA_ARGS[@]}" --mpich-version "$MPICH_VERSION" dev
        fi

        echo "[PASS] All tests completed successfully"
        ;;

    "test-core")
        echo "=== Testing SST-Core Build ==="
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE" ./test-local-build.sh "${EXTRA_ARGS[@]}" --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" core
        else
            ./test-local-build.sh "${EXTRA_ARGS[@]}" --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" core
        fi
        ;;

    "test-full")
        echo "=== Testing SST-Full Build ==="
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE" ./test-local-build.sh "${EXTRA_ARGS[@]}" --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" full
        else
            ./test-local-build.sh "${EXTRA_ARGS[@]}" --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" full
        fi
        ;;

    "test-dev")
        echo "=== Testing Development Build ==="
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE" ./test-local-build.sh "${EXTRA_ARGS[@]}" --mpich-version "$MPICH_VERSION" dev
        else
            ./test-local-build.sh "${EXTRA_ARGS[@]}" --mpich-version "$MPICH_VERSION" dev
        fi
        ;;

    "test-custom")
        if [ -z "$REPO" ] || [ -z "$REF" ]; then
            echo "ERROR: Custom builds require --repo and --ref options"
            echo "Example: $0 test-custom --repo https://github.com/sstsimulator/sst-core.git --ref main"
            exit 1
        fi
        echo "=== Testing Custom Build ==="
        echo "Repository: $REPO"
        echo "Reference: $REF"

        # Build arguments for the new custom build script
        CUSTOM_BUILD_ARGS=(
            --core-repo "$REPO"
            --core-ref "$REF"
            --mpich-version "$MPICH_VERSION"
            --validate
        )

        # Add container engine override if specified
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CUSTOM_BUILD_ARGS+=(--engine "$CONTAINER_ENGINE_OVERRIDE")
        fi

        # Add extra args (like --no-cache, --cleanup)
        if [[ "${EXTRA_ARGS[*]}" =~ --no-cache ]]; then
            CUSTOM_BUILD_ARGS+=(--no-cache)
        fi
        if [[ "${EXTRA_ARGS[*]}" =~ --cleanup ]]; then
            CUSTOM_BUILD_ARGS+=(--cleanup)
        fi

        # Execute the new modular custom build script
        ./scripts/build/custom-build.sh "${CUSTOM_BUILD_ARGS[@]}"
        ;;

    "test-experiment")
        if [ -z "$EXPERIMENT_NAME" ]; then
            echo "ERROR: Experiment builds require --experiment-name option"
            echo "Example: $0 test-experiment --experiment-name phold-example"
            exit 1
        fi
        echo "=== Testing Experiment Build (New Modular System) ==="
        echo "Experiment Name: $EXPERIMENT_NAME"

        # Build arguments for the new experiment build script
        EXPERIMENT_BUILD_ARGS=(
            --experiment-name "$EXPERIMENT_NAME"
            --validation quick
        )

        # Add base image if specified
        if [ -n "$BASE_IMAGE" ]; then
            EXPERIMENT_BUILD_ARGS+=(--base-image "$BASE_IMAGE")
            echo "Base Image: $BASE_IMAGE"
        fi

        # Add container engine override if specified
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            # Note: experiment-build.sh should detect container engine automatically
            # but we can set environment variable for consistency
            export CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE"
        fi

        # Add extra args (like --no-cache, --cleanup)
        if [[ "${EXTRA_ARGS[*]}" =~ --no-cache ]]; then
            EXPERIMENT_BUILD_ARGS+=(--no-cache)
        fi

        # Execute the new modular experiment build script
        ./scripts/build/experiment-build.sh "${EXPERIMENT_BUILD_ARGS[@]}"
        ;;

    "validate")
        if [ ${#REMAINING_ARGS[@]} -eq 0 ]; then
            echo "ERROR: validate command requires IMAGE argument"
            echo "Example: $0 validate localhost:5000/sst-core:15.0.0-amd64"
            exit 1
        fi
        IMAGE="${REMAINING_ARGS[0]}"
        VALIDATION_TYPE="${REMAINING_ARGS[1]:-quick}"
        echo "=== Validating Container Image ==="
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE" ./quick-validate.sh "$IMAGE" "$VALIDATION_TYPE"
        else
            ./quick-validate.sh "$IMAGE" "$VALIDATION_TYPE"
        fi
        ;;

    "clean")
        echo "=== Cleaning Up Test Artifacts ==="

        # Set container engine if overridden
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            DOCKER_CMD="$CONTAINER_ENGINE_OVERRIDE"
        elif [ -n "${CONTAINER_ENGINE}" ]; then
            DOCKER_CMD="${CONTAINER_ENGINE}"
        else
            # Auto-detect
            if command -v podman &> /dev/null; then
                DOCKER_CMD="podman"
            elif command -v docker &> /dev/null; then
                DOCKER_CMD="docker"
            else
                echo "ERROR: No container engine found"
                exit 1
            fi
        fi

        # Clean up test images
        echo "Removing test images..."
        $DOCKER_CMD images | grep -E "localhost:5000/sst|sst.*test" | awk '{print $3}' | xargs -r $DOCKER_CMD rmi -f || true

        # Clean build cache
        echo "Cleaning build cache..."
        $DOCKER_CMD builder prune -f || true

        # Remove temporary files
        echo "Cleaning temporary files..."
        rm -f .last_built_image
        rm -f Containerfiles/*.log

        echo "[PASS] Cleanup completed"
        ;;

    "download")
        if [ ${#REMAINING_ARGS[@]} -gt 0 ]; then
            VERSION="${REMAINING_ARGS[0]}"
        fi
        echo "=== Downloading Source Tarballs ==="
        echo "SST Version: $VERSION"
        echo "MPICH Version: $MPICH_VERSION"
        cd Containerfiles
        ./download_tarballs.sh "$VERSION" "$MPICH_VERSION"
        cd ..
        echo "[PASS] Downloads completed"
        ;;

    "setup")
        echo "=== Setting Up Local Testing Environment ==="

        # Set container engine for this session if overridden
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            export CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE"
        fi

        # Auto-detect and check container engine
        if [ -z "${CONTAINER_ENGINE}" ]; then
            if command -v podman &> /dev/null; then
                DOCKER_CMD="podman"
            elif command -v docker &> /dev/null; then
                DOCKER_CMD="docker"
            else
                echo "ERROR: No container engine found"
                echo "Please install either Docker or Podman:"
                echo "  Docker: https://docs.docker.com/get-docker/"
                echo "  Podman: https://podman.io/getting-started/installation"
                exit 1
            fi
        else
            DOCKER_CMD="${CONTAINER_ENGINE}"
            if ! command -v $DOCKER_CMD &> /dev/null; then
                echo "ERROR: $DOCKER_CMD not found"
                echo "Please install the specified container engine"
                exit 1
            fi
        fi
        echo "[PASS] Container engine: $DOCKER_CMD"

        # Check if we can run containers
        if ! $DOCKER_CMD run --rm hello-world &> /dev/null; then
            echo "[WARN] Cannot run containers. You may need to start the container daemon or check permissions."
        else
            echo "[PASS] Container execution: Working"
        fi

        # Download default sources
        echo "Downloading default source tarballs..."
        cd Containerfiles
        ./download_tarballs.sh "$VERSION" "$MPICH_VERSION"
        cd ..

        echo "[PASS] Setup completed"
        echo ""
        echo "Next steps:"
        echo "  $0 test-core           # Test basic core build"
        echo "  $0 test-all            # Run full test suite"
        ;;

    "benchmark")
        echo "=== Running Build Performance Benchmark ==="
        echo "This will build without cache to get accurate timing..."

        # Set container engine if overridden
        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            DOCKER_CMD="$CONTAINER_ENGINE_OVERRIDE"
        elif [ -n "${CONTAINER_ENGINE}" ]; then
            DOCKER_CMD="${CONTAINER_ENGINE}"
        else
            # Auto-detect
            if command -v podman &> /dev/null; then
                DOCKER_CMD="podman"
            elif command -v docker &> /dev/null; then
                DOCKER_CMD="docker"
            else
                echo "ERROR: No container engine found"
                exit 1
            fi
        fi

        start_time=$(date +%s)

        if [ -n "$CONTAINER_ENGINE_OVERRIDE" ]; then
            CONTAINER_ENGINE="$CONTAINER_ENGINE_OVERRIDE" ./test-local-build.sh --no-cache --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" core
        else
            ./test-local-build.sh --no-cache --sst-version "$VERSION" --mpich-version "$MPICH_VERSION" core
        fi

        end_time=$(date +%s)
        duration=$((end_time - start_time))

        # Get image info if it exists
        IMAGE_TAG="localhost:5000/sst-core:${VERSION}-$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')"
        if $DOCKER_CMD image inspect "$IMAGE_TAG" &> /dev/null; then
            image_size_bytes=$($DOCKER_CMD image inspect "$IMAGE_TAG" --format='{{.Size}}')
            image_size_mb=$((image_size_bytes / 1024 / 1024))
        else
            image_size_mb="unknown"
        fi

        echo ""
        echo "=== BENCHMARK RESULTS ==="
        echo "Date: $(date)"
        echo "Build Duration: ${duration}s"
        echo "Image Size: ${image_size_mb}MB"
        echo "SST Version: $VERSION"
        echo "MPICH Version: $MPICH_VERSION"
        echo "Architecture: $(uname -m)"
        echo "Container Engine: $DOCKER_CMD"

        # Save results
        {
            echo "$(date +%s),$(date),$duration,$image_size_mb,$VERSION,$MPICH_VERSION,$(uname -m),$DOCKER_CMD"
        } >> benchmark_results.csv

        echo ""
        echo "Results saved to benchmark_results.csv"
        ;;

    *)
        echo "ERROR: Unknown command: $COMMAND"
        show_usage
        exit 1
        ;;
esac