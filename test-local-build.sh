#!/bin/bash
# Local Container Build Testing Script
# Mirrors GitHub Actions build process for single architecture testing

set -euo pipefail  # Exit on any error, undefined variables, and pipe failures

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/logging.sh"
source "${SCRIPT_DIR}/scripts/lib/platform.sh"
source "${SCRIPT_DIR}/scripts/lib/validation.sh"
source "${SCRIPT_DIR}/scripts/lib/github-actions.sh"

# Configuration
REGISTRY="localhost:5000"  # Local registry for testing
BUILD_NCPUS=4
PLATFORM=$(uname -m)

# Auto-detect container engine if not specified
CONTAINER_ENGINE=$(detect_container_engine || echo "podman")

# Supported build types matching GitHub Actions
VALID_CONTAINER_TYPES=("core" "full" "dev" "custom" "experiment")
VALID_SST_VERSIONS=("14.0.0" "14.1.0" "15.0.0" "15.1.0")
DEFAULT_SST_VERSION="15.0.0"
DEFAULT_MPICH_VERSION="4.0.2"

# Function to show usage
show_usage() {
    cat << EOF
Local Container Build Testing Script

Usage: $0 [OPTIONS] CONTAINER_TYPE

This script replicates the GitHub Actions build process locally for testing
containerfile changes before pushing to GitHub.

CONTAINER_TYPES:
  core        Build SST-core only (using Containerfile)
  full        Build SST-core + SST-elements (using Containerfile)
  dev         Build development version (using Containerfile.dev)
  custom      Build from custom repositories (using Containerfile.tag)
  experiment  Build from experiment Containerfile

OPTIONS:
  --sst-version VERSION     SST version for release builds (default: $DEFAULT_SST_VERSION)
  --mpich-version VERSION   MPICH version (default: $DEFAULT_MPICH_VERSION)
  --sst-core-repo URL       Custom SST-core repo (for custom/dev builds)
  --sst-core-ref REF        SST-core git reference (for custom/dev builds)
  --sst-elements-repo URL   Custom SST-elements repo (for custom/dev builds)
  --sst-elements-ref REF    SST-elements git reference (for custom/dev builds)
  --experiment-name NAME    Experiment name (for experiment builds)
  --base-image IMAGE        Base image (for experiment builds)
  --no-cache               Build without using cache
  --validate-only          Only validate existing images, don't build
  --cleanup                Clean up after successful build
  --registry URL           Registry to use (default: $REGISTRY)
  --docker                 Use docker container engine
  --podman                 Use podman container engine
  --help                   Show this help

EXAMPLES:
  # Test core build with defaults
  $0 core

  # Test full build with specific SST version
  $0 --sst-version 15.1.0 full

  # Test custom build from GitHub main branch
  $0 --sst-core-repo https://github.com/sstsimulator/sst-core.git \\
     --sst-core-ref main \\
     --sst-elements-repo https://github.com/sstsimulator/sst-elements.git \\
     --sst-elements-ref main \\
     custom

  # Test dev build (no cache, cleanup after)
  $0 --no-cache --cleanup dev

  # Validate existing images
  $0 --validate-only core

ENVIRONMENT VARIABLES:
  CONTAINER_ENGINE    Container engine to use (podman/docker)
  BUILD_NCPUS         Number of CPU cores for builds (default: 4)

EOF
}

# Parse command line arguments
CONTAINER_TYPE=""
SST_VERSION="$DEFAULT_SST_VERSION"
MPICH_VERSION="$DEFAULT_MPICH_VERSION"
SST_CORE_REPO=""
SST_CORE_REF=""
SST_ELEMENTS_REPO=""
SST_ELEMENTS_REF=""
EXPERIMENT_NAME=""
BASE_IMAGE=""
NO_CACHE=false
VALIDATE_ONLY=false
CLEANUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --sst-version)
            SST_VERSION="$2"
            shift 2
            ;;
        --mpich-version)
            MPICH_VERSION="$2"
            shift 2
            ;;
        --sst-core-repo)
            SST_CORE_REPO="$2"
            shift 2
            ;;
        --sst-core-ref)
            SST_CORE_REF="$2"
            shift 2
            ;;
        --sst-elements-repo)
            SST_ELEMENTS_REPO="$2"
            shift 2
            ;;
        --sst-elements-ref)
            SST_ELEMENTS_REF="$2"
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
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --validate-only)
            VALIDATE_ONLY=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --docker)
            CONTAINER_ENGINE="docker"
            shift
            ;;
        --podman)
            CONTAINER_ENGINE="podman"
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        -*)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$CONTAINER_TYPE" ]; then
                CONTAINER_TYPE="$1"
            else
                log_error "Multiple container types specified"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$CONTAINER_TYPE" ]; then
    log_error "Container type is required"
    show_usage
    exit 1
fi

if [[ ! " ${VALID_CONTAINER_TYPES[@]} " =~ " ${CONTAINER_TYPE} " ]]; then
    log_error "Invalid container type: $CONTAINER_TYPE"
    log_error "Valid types: ${VALID_CONTAINER_TYPES[*]}"
    exit 1
fi

# Validate SST version for release builds
if [[ "$CONTAINER_TYPE" =~ ^(core|full)$ ]]; then
    if [[ ! " ${VALID_SST_VERSIONS[@]} " =~ " ${SST_VERSION} " ]]; then
        log_warning "SST version ${SST_VERSION} may not be valid."
        log_warning "Known valid versions: ${VALID_SST_VERSIONS[*]}"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# Detect platform architecture
case "$PLATFORM" in
    x86_64)
        DOCKER_PLATFORM="linux/amd64"
        ARCH="amd64"
        ;;
    aarch64|arm64)
        DOCKER_PLATFORM="linux/arm64"
        ARCH="arm64"
        ;;
    *)
        log_error "Unsupported platform: $PLATFORM"
        log_error "Supported platforms: x86_64, aarch64/arm64"
        exit 1
        ;;
esac

# Validate container engine
if ! validate_container_engine "$CONTAINER_ENGINE"; then
    log_error "Container engine validation failed"
    exit 1
fi

log_info "=== Local Container Build Test ==="
log_info "Container Type: $CONTAINER_TYPE"
log_info "Platform: $(detect_platform)"
log_info "Container Engine: $CONTAINER_ENGINE"
log_info "Registry: $REGISTRY"
log_info "SST Version: $SST_VERSION"
log_info "MPICH Version: $MPICH_VERSION"

# Function to download source tarballs
download_sources() {
    log_info "Downloading source files..."

    cd Containerfiles

    # Download MPICH if needed
    if [ ! -f "mpich-${MPICH_VERSION}.tar.gz" ]; then
        log_info "Downloading MPICH ${MPICH_VERSION}..."
        wget "https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz" --no-check-certificate
    else
        log_info "MPICH ${MPICH_VERSION} already available"
    fi

    # Download SST sources for release builds
    if [[ "$CONTAINER_TYPE" =~ ^(core|full)$ ]]; then
        if [ ! -f "sstcore-${SST_VERSION}.tar.gz" ]; then
            log_info "Downloading SST-core ${SST_VERSION}..."
            wget "https://github.com/sstsimulator/sst-core/releases/download/v${SST_VERSION}_Final/sstcore-${SST_VERSION}.tar.gz" --no-check-certificate
        else
            log_info "SST-core ${SST_VERSION} already available"
        fi

        if [[ "$CONTAINER_TYPE" == "full" ]]; then
            if [ ! -f "sstelements-${SST_VERSION}.tar.gz" ]; then
                log_info "Downloading SST-elements ${SST_VERSION}..."
                wget "https://github.com/sstsimulator/sst-elements/releases/download/v${SST_VERSION}_Final/sstelements-${SST_VERSION}.tar.gz" --no-check-certificate
            else
                log_info "SST-elements ${SST_VERSION} already available"
            fi
        fi
    fi

    cd ..
    log_success "Source files ready"
}

# Function to build container image
build_container() {
    local containerfile=""
    local build_target=""
    local context="Containerfiles"
    local tag_name=""
    local build_args=()

    # Configure build parameters based on container type
    case "$CONTAINER_TYPE" in
        "core")
            containerfile="Containerfiles/Containerfile"
            build_target="sst-core"
            tag_name="${REGISTRY}/sst-core:${SST_VERSION}-${ARCH}"
            build_args+=(
                "--build-arg" "SSTver=${SST_VERSION}"
                "--build-arg" "mpich=${MPICH_VERSION}"
                "--build-arg" "NCPUS=${BUILD_NCPUS}"
            )
            ;;
        "full")
            containerfile="Containerfiles/Containerfile"
            build_target="sst-full"
            tag_name="${REGISTRY}/sst-full:${SST_VERSION}-${ARCH}"
            build_args+=(
                "--build-arg" "SSTver=${SST_VERSION}"
                "--build-arg" "mpich=${MPICH_VERSION}"
                "--build-arg" "NCPUS=${BUILD_NCPUS}"
            )
            ;;
        "dev")
            containerfile="Containerfiles/Containerfile.dev"
            tag_name="${REGISTRY}/sst-dev:latest-${ARCH}"
            build_args+=(
                "--build-arg" "mpich=${MPICH_VERSION}"
                "--build-arg" "NCPUS=${BUILD_NCPUS}"
            )
            ;;
        "custom")
            containerfile="Containerfiles/Containerfile.tag"
            if [ -z "$SST_CORE_REPO" ]; then
                log_error "Custom builds require --sst-core-repo"
                exit 1
            fi
            if [ -z "$SST_CORE_REF" ]; then
                log_error "Custom builds require --sst-core-ref"
                exit 1
            fi

            if [ -n "$SST_ELEMENTS_REPO" ]; then
                build_target="full-build"
                tag_name="${REGISTRY}/sst-custom:${SST_CORE_REF}-full-${ARCH}"
                build_args+=(
                    "--build-arg" "SSTElementsRepo=${SST_ELEMENTS_REPO}"
                    "--build-arg" "elementsTag=${SST_ELEMENTS_REF:-main}"
                )
            else
                build_target="core-build"
                tag_name="${REGISTRY}/sst-custom:${SST_CORE_REF}-${ARCH}"
            fi

            build_args+=(
                "--build-arg" "SSTrepo=${SST_CORE_REPO}"
                "--build-arg" "tag=${SST_CORE_REF}"
                "--build-arg" "mpich=${MPICH_VERSION}"
                "--build-arg" "NCPUS=${BUILD_NCPUS}"
            )
            ;;
        "experiment")
            containerfile="Containerfiles/Containerfile.experiment"
            if [ -z "$EXPERIMENT_NAME" ]; then
                log_error "Experiment builds require --experiment-name"
                exit 1
            fi
            tag_name="${REGISTRY}/sst-experiment/${EXPERIMENT_NAME}:latest-${ARCH}"
            if [ -n "$BASE_IMAGE" ]; then
                build_args+=("--build-arg" "BASE_IMAGE=${BASE_IMAGE}")
            fi
            ;;
    esac

    # Add no-cache flag if requested
    if [ "$NO_CACHE" = true ]; then
        build_args+=("--no-cache")
    fi

    # Add platform specification
    build_args+=("--platform" "$DOCKER_PLATFORM")

    log_info "Building container: $tag_name"
    log_info "Using containerfile: $containerfile"
    if [ -n "$build_target" ]; then
        log_info "Build target: $build_target"
        build_args+=("--target" "$build_target")
    fi

    # Execute build
    set -x
    "$CONTAINER_ENGINE" build \
        "${build_args[@]}" \
        --tag "$tag_name" \
        --file "$containerfile" \
        "$context"
    set +x

    echo "$tag_name" > .last_built_image
    log_success "Build completed: $tag_name"
}

# Function to validate built container
validate_built_container() {
    local tag_name="$1"
    if [ -z "$tag_name" ] && [ -f ".last_built_image" ]; then
        tag_name=$(cat .last_built_image)
    fi

    if [ -z "$tag_name" ]; then
        log_error "No image tag specified for validation"
        exit 1
    fi

    log_info "Validating container: $tag_name"

    # Use standardized validation from validation.sh
    if validate_container "$CONTAINER_ENGINE" "$tag_name" "$CONTAINER_TYPE"; then
        log_success "Container validation passed"
    else
        log_error "Container validation failed"
        exit 1
    fi
}

# Function to cleanup temporary files and images
cleanup() {
    log_info "Cleaning up..."

    if [ -f ".last_built_image" ]; then
        local tag_name
        tag_name=$(cat .last_built_image)
        log_info "Removing image: $tag_name"
        "$CONTAINER_ENGINE" rmi "$tag_name" || log_warning "Failed to remove image"
        rm -f .last_built_image
    fi

    # Clean up build cache
    "$CONTAINER_ENGINE" builder prune -f || log_warning "Failed to prune build cache"

    log_success "Cleanup completed"
}

# Function to run complete test sequence
run_test_sequence() {
    log_info "Starting local build test sequence..."

    # Only download and build if not validate-only mode
    if [ "$VALIDATE_ONLY" != true ]; then
        # Pre-build checks
        if ! [ -d "Containerfiles" ]; then
            log_error "Containerfiles directory not found. Please run from project root."
            exit 1
        fi

        # Download sources
        download_sources

        # Build container
        build_container
    fi

    # Validate container
    validate_built_container

    # Cleanup if requested
    if [ "$CLEANUP" = true ]; then
        cleanup
    fi

    log_success "Test sequence completed successfully!"
}

# Trap to cleanup on exit if something goes wrong
trap cleanup EXIT

# Run the test sequence
run_test_sequence