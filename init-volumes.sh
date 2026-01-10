#!/bin/bash
# Initialize Docker volumes for VS Code Dev Container
# This script ensures proper permissions are set before the container starts
# Exit on any error - no silent failures!

set -e  # Exit immediately if any command fails
set -u  # Exit if undefined variable is used
set -o pipefail  # Catch errors in pipes

# Configuration
VSCODE_VOLUME="cpp-dev-vscode-server"
CACHE_VOLUME="cpp-dev-cache"
IMAGE="bmigeri/cpp-dev:latest-development"
TARGET_UID="1000"
TARGET_GID="1000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions for colored output
info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1" >&2
}

fatal() {
    error "$1"
    exit 1
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        fatal "Docker is not installed or not in PATH"
    fi
    
    if ! docker info &> /dev/null; then
        fatal "Docker daemon is not running or not accessible"
    fi
    
    success "Docker is available"
}

# Create volume if it doesn't exist
create_volume() {
    local volume_name=$1
    
    if docker volume inspect "$volume_name" &> /dev/null; then
        info "Volume '$volume_name' already exists"
    else
        info "Creating volume '$volume_name'..."
        if ! docker volume create "$volume_name" &> /dev/null; then
            fatal "Failed to create volume '$volume_name'"
        fi
        success "Created volume '$volume_name'"
    fi
}

# Check if image is available
check_image() {
    info "Checking for image '$IMAGE'..."
    
    if ! docker image inspect "$IMAGE" &> /dev/null; then
        warn "Image '$IMAGE' not found locally"
        info "Pulling image..."
        
        if ! docker pull "$IMAGE"; then
            fatal "Failed to pull image '$IMAGE'"
        fi
        success "Pulled image '$IMAGE'"
    else
        success "Image '$IMAGE' is available"
    fi
}

# Fix permissions on volumes
fix_permissions() {
    info "Fixing permissions on volumes..."
    
    # Run temporary container as root to fix permissions
    if ! docker run --rm --user root \
        -v "${VSCODE_VOLUME}:/tmp/vs" \
        -v "${CACHE_VOLUME}:/tmp/cache" \
        "$IMAGE" \
        bash -c "
            set -e
            echo 'Creating directory structure...'
            mkdir -p /tmp/vs/bin /tmp/vs/data /tmp/cache
            
            echo 'Setting ownership to ${TARGET_UID}:${TARGET_GID}...'
            chown -R ${TARGET_UID}:${TARGET_GID} /tmp/vs /tmp/cache
            
            echo 'Setting permissions to 755...'
            chmod -R 755 /tmp/vs /tmp/cache
            
            echo 'Permissions fixed successfully'
        "; then
        fatal "Failed to fix permissions on volumes"
    fi
    
    success "Permissions fixed"
}

# Verify permissions are correct
verify_permissions() {
    info "Verifying permissions..."
    
    # Test that developer user can write to the volume
    if ! docker run --rm \
        -v "${VSCODE_VOLUME}:/test" \
        "$IMAGE" \
        bash -c "
            set -e
            touch /test/verify-write 2>&1
            rm /test/verify-write 2>&1
        " > /dev/null 2>&1; then
        fatal "Verification failed: developer user cannot write to volume"
    fi
    
    success "Verification passed - volumes are writable"
}

# Main execution
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    info "Dev Container Volume Initialization"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Step 1: Check Docker
    check_docker
    echo ""
    
    # Step 2: Create volumes
    info "Setting up volumes..."
    create_volume "$VSCODE_VOLUME"
    create_volume "$CACHE_VOLUME"
    echo ""
    
    # Step 3: Check/pull image
    check_image
    echo ""
    
    # Step 4: Fix permissions
    fix_permissions
    echo ""
    
    # Step 5: Verify
    verify_permissions
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "Volume initialization complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    info "Volumes ready:"
    echo "  • $VSCODE_VOLUME"
    echo "  • $CACHE_VOLUME"
    echo ""
}

# Run main function
main "$@"