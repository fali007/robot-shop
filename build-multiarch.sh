#!/bin/bash

# Multiplatform Docker Build Script using Docker Buildx for Robot Shop
# This script builds Docker images for multiple architectures using buildx

set -e

# Configuration
IMAGE_REPO="${IMAGE_REPO:-quay.io/agentbench}"
TAG="${TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Services to build
SERVICES=(
    "cart:cart"
    "catalogue:catalogue"
    "dispatch:dispatch"
    "payment:payment"
    "ratings:ratings"
    "shipping:shipping"
    "user:user"
    "web:web"
    "mongodb:mongo"
    "mysql-db:mysql"
)

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    print_info "Docker version: $(docker --version)"
}

# Check if buildx is available
check_buildx() {
    if ! docker buildx version &> /dev/null; then
        print_error "Docker Buildx is not available"
        print_info "Please install Docker 19.03 or later with buildx support"
        exit 1
    fi
    print_info "Docker Buildx version: $(docker buildx version)"
}

# Setup buildx builder
setup_builder() {
    local builder_name="robotshop-builder"
    
    print_step "Setting up buildx builder..."
    
    # Check if builder already exists
    if docker buildx inspect "$builder_name" &> /dev/null; then
        print_info "Builder '$builder_name' already exists, using it"
        docker buildx use "$builder_name"
    else
        print_info "Creating new builder '$builder_name'"
        docker buildx create --name "$builder_name" --use --bootstrap
    fi
    
    # Inspect builder
    docker buildx inspect --bootstrap
}

# Build and push a single service
build_service() {
    local service_name=$1
    local service_dir=$2
    local image_name="${IMAGE_REPO}/rs-${service_name}:${TAG}"
    
    print_step "Building $service_name from $service_dir/"
    print_info "Image: $image_name"
    print_info "Platforms: $PLATFORMS"
    
    if [ "$DRY_RUN" = true ]; then
        print_warn "DRY RUN: Would build $image_name"
        return 0
    fi
    
    if [ "$PUSH" = true ]; then
        docker buildx build \
            --platform "$PLATFORMS" \
            --push \
            -t "$image_name" \
            "$service_dir/"
    else
        docker buildx build \
            --platform "$PLATFORMS" \
            --load \
            -t "$image_name" \
            "$service_dir/"
    fi
    
    if [ $? -eq 0 ]; then
        print_info "✓ Successfully built $image_name"
    else
        print_error "✗ Failed to build $image_name"
        exit 1
    fi
}

# Build all services
build_all() {
    print_header "Building Multi-Architecture Images"
    print_info "Repository: $IMAGE_REPO"
    print_info "Tag: $TAG"
    print_info "Platforms: $PLATFORMS"
    echo ""
    
    local total=${#SERVICES[@]}
    local current=0
    
    for service_info in "${SERVICES[@]}"; do
        current=$((current + 1))
        IFS=':' read -r service_name service_dir <<< "$service_info"
        
        echo ""
        print_info "[$current/$total] Processing $service_name"
        build_service "$service_name" "$service_dir"
    done
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build multiplatform Docker images for Robot Shop using Docker Buildx

OPTIONS:
    -r, --repo REPO         Image repository (default: quay.io/agentbench)
    -t, --tag TAG           Image tag (default: latest)
    -p, --platforms PLAT    Comma-separated platforms (default: linux/amd64,linux/arm64)
    --no-push               Build locally without pushing to registry
    --push                  Build and push to registry (default)
    --dry-run               Show what would be built without building
    --setup-builder         Setup buildx builder and exit
    --remove-builder        Remove buildx builder and exit
    -h, --help              Display this help message

EXAMPLES:
    # Build and push all images with default settings
    $0

    # Build with custom repository and tag
    $0 --repo myrepo/robotshop --tag v1.0.0

    # Build for specific platforms
    $0 --platforms linux/amd64,linux/arm64,linux/arm/v7

    # Build locally without pushing
    $0 --no-push

    # Dry run to see what would be built
    $0 --dry-run

    # Setup builder only
    $0 --setup-builder

ENVIRONMENT VARIABLES:
    IMAGE_REPO              Image repository (can be set instead of -r)
    TAG                     Image tag (can be set instead of -t)
    PLATFORMS               Target platforms (can be set instead of -p)

NOTES:
    - Docker Buildx automatically creates and pushes manifest lists
    - When using --push, images are pushed directly to the registry
    - When using --no-push with multiple platforms, only the native platform is loaded
    - The builder instance is reused across runs for better performance

EOF
}

# Parse command line arguments
PUSH=true
DRY_RUN=false
SETUP_ONLY=false
REMOVE_BUILDER=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--repo)
            IMAGE_REPO="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -p|--platforms)
            PLATFORMS="$2"
            shift 2
            ;;
        --no-push)
            PUSH=false
            shift
            ;;
        --push)
            PUSH=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --setup-builder)
            SETUP_ONLY=true
            shift
            ;;
        --remove-builder)
            REMOVE_BUILDER=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    print_header "Robot Shop Multi-Architecture Build (Buildx)"
    
    check_docker
    check_buildx
    
    if [ "$REMOVE_BUILDER" = true ]; then
        print_info "Removing builder 'robotshop-builder'"
        docker buildx rm robotshop-builder || true
        print_info "Builder removed"
        exit 0
    fi
    
    setup_builder
    
    if [ "$SETUP_ONLY" = true ]; then
        print_info "Builder setup complete"
        exit 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_warn "DRY RUN MODE - No images will be built"
    fi
    
    if [ "$PUSH" = false ]; then
        print_warn "Building locally without pushing to registry"
        print_warn "Note: Only native platform will be loaded when building multiple platforms"
    fi
    
    build_all
    
    print_header "Build Complete!"
    
    if [ "$DRY_RUN" = false ]; then
        if [ "$PUSH" = true ]; then
            print_info "All images have been built and pushed to: $IMAGE_REPO"
            print_info "Tag: $TAG"
            print_info "Supported platforms: $PLATFORMS"
            echo ""
            print_info "You can pull images using:"
            echo "  docker pull ${IMAGE_REPO}/rs-<service>:${TAG}"
            echo ""
            print_info "Docker will automatically select the correct architecture"
        else
            print_info "All images have been built locally"
            print_info "Use --push to push images to registry"
        fi
    fi
}

main

# Made with Bob
