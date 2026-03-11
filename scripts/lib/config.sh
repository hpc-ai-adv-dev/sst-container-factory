#!/bin/bash
# Centralized configuration for test environments
# Provides default values and environment variable handling

set -euo pipefail

# path resolution for library scripts (only set if not already defined)
if [[ -z "${SCRIPT_LIB_DIR:-}" ]]; then
    readonly SCRIPT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Container and build configuration
DEFAULT_REGISTRY="${REGISTRY:-localhost:5000}"
DEFAULT_MPICH_VERSION="${MPICH_VERSION:-4.0.2}"
DEFAULT_BUILD_NCPUS="${BUILD_NCPUS:-4}"
DEFAULT_SST_VERSION="15.0.0"

# Container size limits (MB)
DEFAULT_MAX_SIZE_CORE=2048
DEFAULT_MAX_SIZE_FULL=4096
DEFAULT_MAX_SIZE_DEV=4096
DEFAULT_MAX_SIZE_EXPERIMENT=8192

# SST repository defaults
DEFAULT_SST_CORE_REPO="https://github.com/sstsimulator/sst-core.git"
DEFAULT_SST_ELEMENTS_REPO="https://github.com/sstsimulator/sst-elements.git"

# Supported build types and versions
VALID_CONTAINER_TYPES=("core" "full" "dev" "custom" "experiment")
VALID_SST_VERSIONS=("14.0.0" "14.1.0" "15.0.0" "15.1.0")

# Get configuration value with fallback
get_config_value() {
    local var_name="$1"
    local default_value="$2"
    echo "${!var_name:-$default_value}"
}

# Validate container type
validate_container_type() {
    local container_type="$1"
    for valid_type in "${VALID_CONTAINER_TYPES[@]}"; do
        if [[ "$container_type" == "$valid_type" ]]; then
            return 0
        fi
    done
    return 1
}

# Validate SST version
validate_sst_version() {
    local sst_version="$1"
    for valid_version in "${VALID_SST_VERSIONS[@]}"; do
        if [[ "$sst_version" == "$valid_version" ]]; then
            return 0
        fi
    done
    return 1
}

# Get default image size limit based on container type
get_default_size_limit() {
    local container_type="$1"
    case "$container_type" in
        "core")
            echo "$DEFAULT_MAX_SIZE_CORE"
            ;;
        "full")
            echo "$DEFAULT_MAX_SIZE_FULL"
            ;;
        "dev"|"custom")
            echo "$DEFAULT_MAX_SIZE_DEV"
            ;;
        "experiment")
            echo "$DEFAULT_MAX_SIZE_EXPERIMENT"
            ;;
        *)
            echo "$DEFAULT_MAX_SIZE_FULL"  # fallback
            ;;
    esac
}

# Generate image tag
generate_image_tag() {
    local registry="$1"
    local container_type="$2"
    local sst_version="$3"
    local arch="${4:-}"

    if [[ -n "$arch" ]]; then
        echo "${registry}/sst-${container_type}:${sst_version}-${arch}"
    else
        echo "${registry}/sst-${container_type}:${sst_version}"
    fi
}

# Generate architecture-specific image tag (matches workflow pattern)
generate_arch_image_tag() {
    local registry="$1"
    local container_type="$2"
    local sst_version="$3"
    local arch="$4"

    echo "${registry}/sst-${container_type}:${sst_version}-${arch}"
}

# Generate base image tag for fat manifest (matches workflow pattern)
generate_base_image_tag() {
    local registry="$1"
    local container_type="$2"
    local sst_version="$3"

    echo "${registry}/sst-${container_type}:${sst_version}"
}