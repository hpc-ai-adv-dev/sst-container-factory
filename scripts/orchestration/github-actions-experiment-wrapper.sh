#!/bin/bash
#
# GitHub Actions Wrapper for Experiment Builds
# Maintains compatibility with existing GitHub Actions workflow interface
#

set -euo pipefail

# Get absolute path to the script and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPTS_ROOT="$PROJECT_ROOT/scripts"

# Source common libraries
source "$SCRIPTS_ROOT/lib/logging.sh"
source "$SCRIPTS_ROOT/lib/github-actions.sh"

# GitHub Actions input mapping
EXPERIMENT_NAME="${INPUT_EXPERIMENT_NAME:-}"
BASE_IMAGE="${INPUT_BASE_IMAGE:-}"
IMAGE_PREFIX="${INPUT_IMAGE_PREFIX:-ghcr.io/$(whoami)}"
TAG_SUFFIX="${INPUT_TAG_SUFFIX:-latest}"
BUILD_PLATFORMS="${INPUT_BUILD_PLATFORMS:-linux/amd64}"
CONTAINERFILE_PATH="${INPUT_CONTAINERFILE_PATH:-}"
DOCKER_CONTEXT="${INPUT_DOCKER_CONTEXT:-}"
NO_CACHE="${INPUT_NO_CACHE:-false}"

# Internal parameters
VALIDATION_MODE="full"  # Default to full validation for GitHub Actions

main() {
    log_info "GitHub Actions Experiment Build Wrapper"

    # Validate required inputs
    if [ -z "$EXPERIMENT_NAME" ]; then
        log_error "experiment_name input is required"
        exit 1
    fi

    # Build arguments array
    local build_args=(
        "--experiment-name" "$EXPERIMENT_NAME"
        "--prefix" "$IMAGE_PREFIX"
        "--tag-suffix" "$TAG_SUFFIX"
        "--platforms" "$BUILD_PLATFORMS"
        "--validation" "$VALIDATION_MODE"
    )

    # Add base image if specified
    if [ -n "$BASE_IMAGE" ]; then
        build_args+=("--base-image" "$BASE_IMAGE")
    fi

    # Add no-cache flag if requested
    if [ "$NO_CACHE" = "true" ]; then
        build_args+=("--no-cache")
    fi

    log_info "Calling experiment build script with:"
    log_info "  Experiment: $EXPERIMENT_NAME"
    log_info "  Base Image: ${BASE_IMAGE:-<none>}"
    log_info "  Platforms: $BUILD_PLATFORMS"
    log_info "  Tag Suffix: $TAG_SUFFIX"
    log_info "  No Cache: $NO_CACHE"

    # Execute the experiment build script
    "$SCRIPTS_ROOT/build/experiment-build.sh" "${build_args[@]}"

    return $?
}

# Run main function
main "$@"