#!/bin/bash
# Quick container validation script
# For rapid testing of existing images without rebuild

set -euo pipefail

# Simple logging functions (avoid complex dependencies)
log_info() { echo "[INFO] $1"; }
log_success() { echo "[SUCCESS] $1"; }
log_warning() { echo "[WARNING] $1"; }
log_error() { echo "[ERROR] $1"; }
log_group_start() { echo "=== $1 ==="; }
log_group_end() { echo; }

# Auto-detect container engine
detect_container_engine() {
    local engine="${CONTAINER_ENGINE:-}"
    if [[ -z "$engine" ]]; then
        if command -v podman &> /dev/null; then
            engine="podman"
        elif command -v docker &> /dev/null; then
            engine="docker"
        else
            echo "podman"  # fallback
            return
        fi
    fi
    echo "$engine"
}

# Auto-detect platform
detect_platform() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "linux/amd64"
            ;;
        aarch64|arm64)
            echo "linux/arm64"
            ;;
        *)
            echo "linux/amd64"  # fallback
            ;;
    esac
}

# Simple validation functions (adapted from validation.sh)
image_exists() {
    local engine="$1"
    local image_tag="$2"
    "$engine" image inspect "$image_tag" &> /dev/null
}

get_image_size_mb() {
    local engine="$1"
    local image_tag="$2"
    local size_bytes
    size_bytes=$("$engine" image inspect "$image_tag" --format='{{.Size}}' 2>/dev/null || echo "0")
    echo $((size_bytes / 1024 / 1024))
}

quick_validate_image() {
    local engine="$1"
    local image_tag="$2"

    log_info "Quick validation of $image_tag"

    if ! image_exists "$engine" "$image_tag"; then
        log_error "Image not found: $image_tag"
        return 1
    fi
    log_success "Image exists"

    local image_size_mb
    image_size_mb=$(get_image_size_mb "$engine" "$image_tag")
    log_info "Image size: ${image_size_mb}MB"

    if "$engine" image inspect "$image_tag" --format='{{.Config.Env}}' &> /dev/null; then
        log_success "Image inspection passed"
    else
        log_warning "Image inspection failed"
        return 1
    fi

    log_success "Quick validation passed"
    return 0
}

no_exec_validate_image() {
    local engine="$1"
    local image_tag="$2"
    local max_size_mb="${3:-2048}"

    log_info "No-exec validation of $image_tag"

    if ! image_exists "$engine" "$image_tag"; then
        log_error "Image not found: $image_tag"
        return 1
    fi
    log_success "Image exists"

    local image_size_mb
    image_size_mb=$(get_image_size_mb "$engine" "$image_tag")
    log_info "Image size: ${image_size_mb}MB"

    if [ "$image_size_mb" -gt "$max_size_mb" ]; then
        log_error "Image size ${image_size_mb}MB exceeds limit ${max_size_mb}MB"
        return 1
    else
        log_success "Image size check passed"
    fi

    local arch
    arch=$("$engine" image inspect "$image_tag" --format='{{.Architecture}}' 2>/dev/null || echo "unknown")
    log_info "Image architecture: $arch"

    log_success "No-exec validation passed"
    return 0
}

# Call the full validation script
full_validate_image() {
    local engine="$1"
    local image_tag="$2"
    local container_type="$3"

    log_info "Delegating to full validation script..."

    # Source and call the comprehensive validation functions
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${script_dir}/scripts/lib/validation.sh" ]]; then
        # Temporarily source what we need for full validation
        source "${script_dir}/scripts/lib/github-actions.sh" || true
        source "${script_dir}/scripts/lib/logging.sh" || true
        source "${script_dir}/scripts/lib/platform.sh" || true
        source "${script_dir}/scripts/lib/validation.sh" || true

        if validate_container "$engine" "$image_tag" "$container_type"; then
            log_success "Full validation passed"
            return 0
        else
            log_error "Full validation failed"
            return 1
        fi
    else
        log_error "Full validation script not found"
        return 1
    fi
}

# Auto-detect container engine if not specified
if [ -z "${CONTAINER_ENGINE:-}" ]; then
    CONTAINER_ENGINE=$(detect_container_engine)
fi
REGISTRY="localhost:5000"

show_usage() {
    cat << EOF
Quick Container Validation Script

Usage: $0 IMAGE_TAG [VALIDATION_TYPE]

Quickly validate existing container images without rebuilding.

IMAGE_TAG:         Full image tag to validate (e.g., localhost:5000/sst-core:15.0.0-amd64)
VALIDATION_TYPE:   Type of validation to perform [default: quick]

VALIDATION TYPES:
  quick       Quick validation without execution tests
  full        Complete validation including functionality tests
  no-exec     Validation without executing container commands

EXAMPLES:
  $0 localhost:5000/sst-core:15.0.0-amd64
  $0 localhost:5000/sst-full:15.0.0-amd64 full
  $0 ghcr.io/hpc-ai-adv-dev/sst-core:15.0.0-amd64 no-exec

EOF
}

if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

IMAGE_TAG="$1"
VALIDATION_TYPE="${2:-quick}"

log_group_start "Container Validation"
log_info "Image: $IMAGE_TAG"
log_info "Validation Type: $VALIDATION_TYPE"
log_info "Container Engine: $CONTAINER_ENGINE"

# Detect platform for validation
TARGET_PLATFORM=$(detect_platform)
log_info "Platform: $TARGET_PLATFORM"

# Determine container type from image name for proper validation
CONTAINER_TYPE="core"  # default
if [[ "$IMAGE_TAG" == *"sst-full"* ]]; then
    CONTAINER_TYPE="full"
elif [[ "$IMAGE_TAG" == *"sst-dev"* ]]; then
    CONTAINER_TYPE="dev"
elif [[ "$IMAGE_TAG" == *"sst-custom"* ]]; then
    CONTAINER_TYPE="custom"
elif [[ "$IMAGE_TAG" == *"experiment"* ]]; then
    CONTAINER_TYPE="experiment"
fi

log_info "Detected container type: $CONTAINER_TYPE"

# Run validation based on type
case "$VALIDATION_TYPE" in
    "quick")
        if quick_validate_image "$CONTAINER_ENGINE" "$IMAGE_TAG"; then
            log_success "Quick validation completed successfully"
            exit_code=0
        else
            log_error "Quick validation failed"
            exit_code=1
        fi
        ;;
    "no-exec")
        if no_exec_validate_image "$CONTAINER_ENGINE" "$IMAGE_TAG"; then
            log_success "No-exec validation completed successfully"
            exit_code=0
        else
            log_error "No-exec validation failed"
            exit_code=1
        fi
        ;;
    "full")
        if full_validate_image "$CONTAINER_ENGINE" "$IMAGE_TAG" "$CONTAINER_TYPE"; then
            log_success "Full validation completed successfully"
            exit_code=0
        else
            log_error "Full validation failed"
            exit_code=1
        fi
        ;;
    *)
        log_error "Unknown validation type: $VALIDATION_TYPE"
        show_usage
        exit 1
        ;;
esac

log_group_end
exit $exit_code