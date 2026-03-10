#!/bin/bash
# Custom SST container build script
# Builds SST containers from any Git repository and branch/tag/commit

set -euo pipefail

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/logging.sh"
source "${SCRIPT_DIR}/../lib/platform.sh"
source "${SCRIPT_DIR}/../lib/validation.sh"
source "${SCRIPT_DIR}/../lib/github-actions.sh"

# Default configuration
DEFAULT_REGISTRY="${REGISTRY:-localhost:5000}"
DEFAULT_MPICH_VERSION="${MPICH_VERSION:-4.0.2}"
DEFAULT_BUILD_NCPUS="${BUILD_NCPUS:-4}"
DEFAULT_SST_CORE_REPO="https://github.com/sstsimulator/sst-core.git"

show_usage() {
    cat << EOF
Custom SST Container Build Script

Build SST containers from any Git repository and branch/tag/commit.
Supports both core-only and full (core+elements) builds.

Usage: $0 [OPTIONS]

Required Options:
  --core-ref REF              SST-core branch, tag, or commit SHA

Optional Options:
  --core-repo URL             SST-core repository URL (default: $DEFAULT_SST_CORE_REPO)
  --elements-repo URL         SST-elements repository URL (for full build)
  --elements-ref REF          SST-elements branch, tag, or commit SHA
  --mpich-version VERSION     MPICH version to use (default: $DEFAULT_MPICH_VERSION)
  --registry URL              Container registry (default: $DEFAULT_REGISTRY)
  --tag-suffix SUFFIX         Custom tag suffix (default: core ref name)
  --build-ncpus NUMBER        Number of CPU cores for build (default: $DEFAULT_BUILD_NCPUS)
  --no-cache                  Build without using cache
  --validate                  Run validation after build
  --validate-quick            Run quick validation (no execution tests)
  --validate-no-exec          Validate without executing any container commands
  --cleanup                   Remove image after successful validation
  --engine ENGINE             Container engine to use (docker/podman)
  --platform PLATFORM         Target platform (linux/amd64, linux/arm64)
  --github-actions            Enable GitHub Actions output format

Examples:
  # Build SST-core from main branch
  $0 --core-ref main

  # Build full SST from custom repositories
  $0 --core-ref v15.1.0 \\
     --elements-repo https://github.com/custom/sst-elements.git \\
     --elements-ref develop

  # Build with custom MPICH version
  $0 --core-ref feature-branch --mpich-version 4.1.0 --no-cache

EOF
}

# Parse command line arguments
SST_CORE_REPO="$DEFAULT_SST_CORE_REPO"
SST_CORE_REF=""
SST_ELEMENTS_REPO=""
SST_ELEMENTS_REF=""
MPICH_VERSION="$DEFAULT_MPICH_VERSION"
REGISTRY="$DEFAULT_REGISTRY"
TAG_SUFFIX=""
BUILD_NCPUS="$DEFAULT_BUILD_NCPUS"
NO_CACHE=false
VALIDATE=false
VALIDATE_QUICK=false
VALIDATE_NO_EXEC=false
CLEANUP=false
CONTAINER_ENGINE=""
TARGET_PLATFORM=""
GITHUB_ACTIONS_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --core-repo)
            SST_CORE_REPO="$2"
            shift 2
            ;;
        --core-ref)
            SST_CORE_REF="$2"
            shift 2
            ;;
        --elements-repo)
            SST_ELEMENTS_REPO="$2"
            shift 2
            ;;
        --elements-ref)
            SST_ELEMENTS_REF="$2"
            shift 2
            ;;
        --mpich-version)
            MPICH_VERSION="$2"
            shift 2
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --tag-suffix)
            TAG_SUFFIX="$2"
            shift 2
            ;;
        --build-ncpus)
            BUILD_NCPUS="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE=true
            shift
            ;;
        --validate)
            VALIDATE=true
            shift
            ;;
        --validate-quick)
            VALIDATE_QUICK=true
            shift
            ;;
        --validate-no-exec)
            VALIDATE_NO_EXEC=true
            shift
            ;;
        --cleanup)
            CLEANUP=true
            shift
            ;;
        --engine)
            CONTAINER_ENGINE="$2"
            shift 2
            ;;
        --platform)
            TARGET_PLATFORM="$2"
            shift 2
            ;;
        --github-actions)
            GITHUB_ACTIONS_MODE=true
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
            log_error "Unexpected argument: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$SST_CORE_REF" ]]; then
    log_error "SST-core reference is required (--core-ref)"
    show_usage
    exit 1
fi

# If elements repo is specified, elements ref is also required
if [[ -n "$SST_ELEMENTS_REPO" && -z "$SST_ELEMENTS_REF" ]]; then
    log_error "SST-elements reference is required when elements repo is specified (--elements-ref)"
    exit 1
fi

# Detect container engine if not specified
if [[ -z "$CONTAINER_ENGINE" ]]; then
    CONTAINER_ENGINE=$(detect_container_engine)
fi

# Validate container engine
if ! validate_container_engine "$CONTAINER_ENGINE"; then
    exit 1
fi

# Detect target platform if not specified
if [[ -z "$TARGET_PLATFORM" ]]; then
    TARGET_PLATFORM=$(detect_platform)
fi

# Validate target platform
if ! validate_platform "$TARGET_PLATFORM"; then
    exit 1
fi

# Check if we can build for target platform locally
if ! can_build_platform "$TARGET_PLATFORM"; then
    log_warning "Cross-platform build detected"
fi

# Determine build type and generate tag
BUILD_TYPE="core-build"
if [[ -n "$SST_ELEMENTS_REPO" ]]; then
    BUILD_TYPE="full-build"
fi

# Generate tag suffix if not provided
if [[ -z "$TAG_SUFFIX" ]]; then
    TAG_SUFFIX="$SST_CORE_REF"
    if [[ -n "$SST_ELEMENTS_REPO" ]]; then
        TAG_SUFFIX="${TAG_SUFFIX}-full"
    fi
fi

# Generate final image tag
ARCH=$(get_arch)
IMAGE_TAG="${REGISTRY}/sst-custom:${TAG_SUFFIX}-${ARCH}"

log_group_start "Custom SST Container Build"
log_info "Build Configuration:"
log_info "  SST Core Repository: $SST_CORE_REPO"
log_info "  SST Core Reference: $SST_CORE_REF"
if [[ -n "$SST_ELEMENTS_REPO" ]]; then
    log_info "  SST Elements Repository: $SST_ELEMENTS_REPO"
    log_info "  SST Elements Reference: $SST_ELEMENTS_REF"
fi
log_info "  MPICH Version: $MPICH_VERSION"
log_info "  Build Type: $BUILD_TYPE"
log_info "  Target Platform: $TARGET_PLATFORM"
log_info "  Container Engine: $CONTAINER_ENGINE"
log_info "  Image Tag: $IMAGE_TAG"
log_group_end

# Build arguments array
build_args=(
    "--file" "Containerfiles/Containerfile.tag"
    "--target" "$BUILD_TYPE"
    "--tag" "$IMAGE_TAG"
    "--build-arg" "SSTrepo=${SST_CORE_REPO}"
    "--build-arg" "tag=${SST_CORE_REF}"
    "--build-arg" "mpich=${MPICH_VERSION}"
    "--build-arg" "NCPUS=${BUILD_NCPUS}"
    "--platform" "$TARGET_PLATFORM"
)

# Add elements-specific build args if building full
if [[ "$BUILD_TYPE" == "full-build" ]]; then
    build_args+=(
        "--build-arg" "SSTElementsRepo=${SST_ELEMENTS_REPO}"
        "--build-arg" "elementsTag=${SST_ELEMENTS_REF}"
    )
fi

# Add cache control
if [[ "$NO_CACHE" == "true" ]]; then
    build_args+=("--no-cache")
fi

# Execute build
log_group_start "Building Container"
start_time=$(date +%s)

if log_exec "Container build" "$CONTAINER_ENGINE" build "${build_args[@]}" "Containerfiles"; then
    end_time=$(date +%s)
    build_time=$((end_time - start_time))
    log_success "Container build completed in ${build_time}s"
else
    log_error "Container build failed"
    exit 1
fi

log_group_end

# Get image size
IMAGE_SIZE_MB=$(get_image_size_mb "$CONTAINER_ENGINE" "$IMAGE_TAG")
log_info "Image size: ${IMAGE_SIZE_MB}MB"

# Report build metrics for GitHub Actions
if [[ "$GITHUB_ACTIONS_MODE" == "true" ]] || is_github_actions; then
    report_build_metrics "$IMAGE_TAG" "$build_time" "$IMAGE_SIZE_MB" "$TARGET_PLATFORM"
fi

# Validate container if requested
if [[ "$VALIDATE" == "true" ]] || [[ "$VALIDATE_QUICK" == "true" ]] || [[ "$VALIDATE_NO_EXEC" == "true" ]]; then
    log_group_start "Validating Container"

    # Determine container type for validation
    VALIDATION_TYPE="custom"
    MAX_SIZE_MB=2048  # 2GB default for custom builds

    if [[ "$VALIDATE_QUICK" == "true" ]]; then
        # Quick validation - just check image exists and can be inspected
        if quick_validate_image "$CONTAINER_ENGINE" "$IMAGE_TAG"; then
            log_success "Quick container validation passed"
        else
            log_error "Quick container validation failed"
            exit 1
        fi
    elif [[ "$VALIDATE_NO_EXEC" == "true" ]]; then
        # No-exec validation - check image and metadata without running commands
        if no_exec_validate_image "$CONTAINER_ENGINE" "$IMAGE_TAG" "$MAX_SIZE_MB"; then
            log_success "No-exec container validation passed"
        else
            log_error "No-exec container validation failed"
            exit 1
        fi
    else
        # Full validation with platform awareness
        if validate_container "$CONTAINER_ENGINE" "$IMAGE_TAG" "$VALIDATION_TYPE" "$MAX_SIZE_MB"; then
            log_success "Container validation passed"
        else
            log_error "Container validation failed"
            exit 1
        fi
    fi

    log_group_end
fi

# Cleanup if requested and validation passed
if [[ "$CLEANUP" == "true" ]]; then
    log_info "Cleaning up image: $IMAGE_TAG"
    if "$CONTAINER_ENGINE" rmi "$IMAGE_TAG" &> /dev/null; then
        log_success "Image cleaned up successfully"
    else
        log_warning "Failed to clean up image"
    fi
fi

log_success "Custom build completed successfully"
log_info "Image: $IMAGE_TAG"

# Output final result for consumption by other scripts
if [[ "$GITHUB_ACTIONS_MODE" == "true" ]] || is_github_actions; then
    set_output "image-tag" "$IMAGE_TAG"
    set_output "build-successful" "true"
fi

exit 0