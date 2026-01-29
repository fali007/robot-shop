#!/bin/bash

# Multiplatform Docker Build Script for Robot Shop
# This script builds Docker images for multiple architectures and creates manifest lists

set -e

# Configuration
IMAGE_REPO="${IMAGE_REPO:-quay.io/agentbench}"
TAG="${TAG:-latest}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    print_info "Docker version: $(docker --version)"
}

# Build images for a specific platform
build_platform() {
    local platform=$1
    local platform_tag=$2
    
    print_header "Building images for $platform"
    
    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_dir <<< "$service_info"
        local image_name="${IMAGE_REPO}/rs-${service_name}:${TAG}-${platform_tag}"
        
        print_info "Building $image_name from $service_dir/"
        docker build --platform "$platform" -t "$image_name" "$service_dir/"
        
        if [ $? -eq 0 ]; then
            print_info "✓ Successfully built $image_name"
        else
            print_error "✗ Failed to build $image_name"
            exit 1
        fi
    done
}

# Push images for all platforms
push_images() {
    print_header "Pushing platform-specific images"
    
    for platform_tag in "amd64" "arm64"; do
        print_info "Pushing $platform_tag images..."
        for service_info in "${SERVICES[@]}"; do
            IFS=':' read -r service_name service_dir <<< "$service_info"
            local image_name="${IMAGE_REPO}/rs-${service_name}:${TAG}-${platform_tag}"
            
            print_info "Pushing $image_name"
            docker push "$image_name"
            
            if [ $? -eq 0 ]; then
                print_info "✓ Successfully pushed $image_name"
            else
                print_error "✗ Failed to push $image_name"
                exit 1
            fi
        done
    done
}

# Create manifest lists
create_manifests() {
    print_header "Creating manifest lists"
    
    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_dir <<< "$service_info"
        local manifest_name="${IMAGE_REPO}/rs-${service_name}:${TAG}"
        local amd64_image="${IMAGE_REPO}/rs-${service_name}:${TAG}-amd64"
        local arm64_image="${IMAGE_REPO}/rs-${service_name}:${TAG}-arm64"
        
        print_info "Creating manifest for $manifest_name"
        
        # Remove existing manifest if it exists
        docker manifest rm "$manifest_name" 2>/dev/null || true
        
        docker manifest create "$manifest_name" \
            "$amd64_image" \
            "$arm64_image"
        
        if [ $? -eq 0 ]; then
            print_info "✓ Successfully created manifest $manifest_name"
        else
            print_error "✗ Failed to create manifest $manifest_name"
            exit 1
        fi
    done
}

# Push manifest lists
push_manifests() {
    print_header "Pushing manifest lists"
    
    for service_info in "${SERVICES[@]}"; do
        IFS=':' read -r service_name service_dir <<< "$service_info"
        local manifest_name="${IMAGE_REPO}/rs-${service_name}:${TAG}"
        
        print_info "Pushing manifest $manifest_name"
        docker manifest push "$manifest_name"
        
        if [ $? -eq 0 ]; then
            print_info "✓ Successfully pushed manifest $manifest_name"
        else
            print_error "✗ Failed to push manifest $manifest_name"
            exit 1
        fi
    done
}

# Display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build multiplatform Docker images for Robot Shop

OPTIONS:
    -r, --repo REPO     Image repository (default: quay.io/agentbench)
    -t, --tag TAG       Image tag (default: latest)
    -a, --amd64-only    Build only amd64 images
    -m, --arm64-only    Build only arm64 images
    -b, --build-only    Build images without pushing
    -p, --push-only     Push existing images and create manifests
    -h, --help          Display this help message

EXAMPLES:
    # Build and push all images with default settings
    $0

    # Build with custom repository and tag
    $0 --repo myrepo/robotshop --tag v1.0.0

    # Build only amd64 images
    $0 --amd64-only

    # Build without pushing
    $0 --build-only

    # Push existing images and create manifests
    $0 --push-only

ENVIRONMENT VARIABLES:
    IMAGE_REPO          Image repository (can be set instead of -r)
    TAG                 Image tag (can be set instead of -t)

EOF
}

# Parse command line arguments
BUILD_AMD64=true
BUILD_ARM64=true
BUILD_ONLY=false
PUSH_ONLY=false

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
        -a|--amd64-only)
            BUILD_ARM64=false
            shift
            ;;
        -m|--arm64-only)
            BUILD_AMD64=false
            shift
            ;;
        -b|--build-only)
            BUILD_ONLY=true
            shift
            ;;
        -p|--push-only)
            PUSH_ONLY=true
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
    print_header "Robot Shop Multiplatform Build"
    print_info "Repository: $IMAGE_REPO"
    print_info "Tag: $TAG"
    echo ""
    
    check_docker
    
    if [ "$PUSH_ONLY" = false ]; then
        if [ "$BUILD_AMD64" = true ]; then
            build_platform "linux/amd64" "amd64"
        fi
        
        if [ "$BUILD_ARM64" = true ]; then
            build_platform "linux/arm64" "arm64"
        fi
    fi
    
    if [ "$BUILD_ONLY" = false ]; then
        push_images
        create_manifests
        push_manifests
        
        print_header "Build Complete!"
        print_info "All images are now available with tag: $TAG"
        print_info "Images support: linux/amd64 and linux/arm64"
        echo ""
        print_info "You can pull images using:"
        echo "  docker pull ${IMAGE_REPO}/rs-<service>:${TAG}"
        echo ""
        print_info "Docker will automatically select the correct architecture for your platform"
    else
        print_header "Build Complete!"
        print_info "Images built locally. Use --push-only to push and create manifests."
    fi
}

main

# Made with Bob
