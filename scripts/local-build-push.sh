#!/bin/bash

# Local Docker Build and Push Script
# Usage: ./scripts/local-build-push.sh [your-github-pat-token]

set -e

# Configuration
VERSION="0.0.1-pre-release"
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VCS_REF=$(git rev-parse --short HEAD)
REGISTRY="ghcr.io"
IMAGE_NAME="billchurch/ssh_test"
PLATFORMS="linux/amd64,linux/arm64"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if PAT token is provided
if [ -z "$1" ]; then
    log_error "GitHub Personal Access Token is required"
    echo "Usage: $0 <github-pat-token>"
    echo ""
    echo "Example:"
    echo "  $0 ghp_xxxxxxxxxxxxxxxxxxxx"
    echo ""
    echo "Make sure your PAT has these scopes:"
    echo "  - repo"
    echo "  - workflow" 
    echo "  - write:packages"
    echo "  - read:packages"
    exit 1
fi

GITHUB_TOKEN="$1"

# Validate we're in the right directory
if [ ! -f "docker/Dockerfile" ] || [ ! -f "docker/Dockerfile.alpine" ]; then
    log_error "Must be run from the repository root directory"
    log_error "Make sure docker/Dockerfile and docker/Dockerfile.alpine exist"
    exit 1
fi

log_info "Starting local build and push for SSH Test Server"
log_info "Version: $VERSION"
log_info "Registry: $REGISTRY"
log_info "Image: $IMAGE_NAME"
log_info "Platforms: $PLATFORMS"
log_info "Build Date: $BUILD_DATE"
log_info "VCS Ref: $VCS_REF"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker Desktop."
    exit 1
fi

# Set up Docker Buildx
log_info "Setting up Docker Buildx..."
docker buildx create --use --name ssh-test-builder --driver docker-container > /dev/null 2>&1 || true
docker buildx inspect --bootstrap > /dev/null 2>&1

# Login to GitHub Container Registry
log_info "Logging in to GitHub Container Registry..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u "$(git config user.name || echo 'github-user')" --password-stdin

if [ $? -eq 0 ]; then
    log_success "Successfully logged in to GHCR"
else
    log_error "Failed to login to GHCR. Check your PAT token and permissions."
    exit 1
fi

# Build and push Debian variant
log_info "Building and pushing Debian variant..."
docker buildx build \
    --platform "$PLATFORMS" \
    --file docker/Dockerfile \
    --build-arg VERSION="$VERSION" \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg VCS_REF="$VCS_REF" \
    --tag "$REGISTRY/$IMAGE_NAME:$VERSION" \
    --tag "$REGISTRY/$IMAGE_NAME:$VERSION-debian" \
    --tag "$REGISTRY/$IMAGE_NAME:debian-latest" \
    --push \
    .

if [ $? -eq 0 ]; then
    log_success "Debian variant built and pushed successfully"
else
    log_error "Failed to build/push Debian variant"
    exit 1
fi

# Build and push Alpine variant  
log_info "Building and pushing Alpine variant..."
docker buildx build \
    --platform "$PLATFORMS" \
    --file docker/Dockerfile.alpine \
    --build-arg VERSION="$VERSION" \
    --build-arg BUILD_DATE="$BUILD_DATE" \
    --build-arg VCS_REF="$VCS_REF" \
    --tag "$REGISTRY/$IMAGE_NAME:$VERSION-alpine" \
    --tag "$REGISTRY/$IMAGE_NAME:alpine-latest" \
    --push \
    .

if [ $? -eq 0 ]; then
    log_success "Alpine variant built and pushed successfully"
else
    log_error "Failed to build/push Alpine variant"
    exit 1
fi

# Clean up buildx builder
log_info "Cleaning up buildx builder..."
docker buildx rm ssh-test-builder > /dev/null 2>&1 || true

# Show final summary
echo ""
log_success "🎉 Build and push completed successfully!"
echo ""
echo "Built and pushed images:"
echo "  📦 $REGISTRY/$IMAGE_NAME:$VERSION"
echo "  📦 $REGISTRY/$IMAGE_NAME:$VERSION-debian"
echo "  📦 $REGISTRY/$IMAGE_NAME:debian-latest"
echo "  📦 $REGISTRY/$IMAGE_NAME:$VERSION-alpine"
echo "  📦 $REGISTRY/$IMAGE_NAME:alpine-latest"
echo ""
echo "Test the images:"
echo "  docker run --rm -p 2222:22 -e SSH_USER=test -e SSH_PASSWORD=test123 $REGISTRY/$IMAGE_NAME:$VERSION-debian"
echo "  docker run --rm -p 2223:22 -e SSH_USER=test -e SSH_PASSWORD=test123 $REGISTRY/$IMAGE_NAME:$VERSION-alpine"
echo ""
echo "View on GitHub:"
echo "  https://github.com/billchurch/ssh_test/pkgs/container/ssh_test"