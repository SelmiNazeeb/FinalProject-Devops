#!/bin/bash

# CloudOps Demo - Docker Images Build Script
# This script builds and pushes Docker images to a container registry

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY=${DOCKER_REGISTRY:-"your-registry"}  # Replace with your registry
TAG=${IMAGE_TAG:-"latest"}
FRONTEND_IMAGE="$REGISTRY/cloudops-frontend:$TAG"
BACKEND_IMAGE="$REGISTRY/cloudops-backend:$TAG"

echo -e "${BLUE}🐳 Building Docker Images for CloudOps Demo${NC}"
echo "============================================="

# Check if Docker is running
check_docker() {
    echo -e "${YELLOW}📋 Checking Docker...${NC}"
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is running${NC}"
}

# Build frontend image
build_frontend() {
    echo -e "${YELLOW}🏗️ Building frontend image...${NC}"
    docker build -t $FRONTEND_IMAGE ./frontend
    echo -e "${GREEN}✅ Frontend image built: $FRONTEND_IMAGE${NC}"
}

# Build backend image
build_backend() {
    echo -e "${YELLOW}🏗️ Building backend image...${NC}"
    docker build -t $BACKEND_IMAGE ./backend
    echo -e "${GREEN}✅ Backend image built: $BACKEND_IMAGE${NC}"
}

# Push images to registry
push_images() {
    echo -e "${YELLOW}📤 Pushing images to registry...${NC}"
    
    # Login to Docker registry (uncomment the appropriate line)
    # docker login  # For Docker Hub
    # aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $REGISTRY  # For ECR
    
    docker push $FRONTEND_IMAGE
    docker push $BACKEND_IMAGE
    
    echo -e "${GREEN}✅ Images pushed successfully${NC}"
}

# Update Kubernetes manifests with new image tags
update_manifests() {
    echo -e "${YELLOW}🔧 Updating Kubernetes manifests...${NC}"
    
    # Update backend deployment
    sed -i.bak "s|image: your-registry/cloudops-backend:.*|image: $BACKEND_IMAGE|g" k8s/07-backend-deployment.yaml
    
    # Update frontend deployment
    sed -i.bak "s|image: your-registry/cloudops-frontend:.*|image: $FRONTEND_IMAGE|g" k8s/09-frontend-deployment.yaml
    
    # Remove backup files
    rm -f k8s/*.bak
    
    echo -e "${GREEN}✅ Kubernetes manifests updated${NC}"
}

# Show image information
show_info() {
    echo -e "${BLUE}📊 Image Information${NC}"
    echo "====================="
    echo -e "${YELLOW}Frontend Image:${NC} $FRONTEND_IMAGE"
    echo -e "${YELLOW}Backend Image:${NC} $BACKEND_IMAGE"
    echo ""
    echo -e "${BLUE}Image sizes:${NC}"
    docker images | grep cloudops
}

# Main execution
main() {
    check_docker
    build_frontend
    build_backend
    
    # Ask if user wants to push to registry
    read -p "Do you want to push images to registry? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        push_images
        update_manifests
    fi
    
    show_info
    
    echo -e "\n${GREEN}🎉 Image build completed successfully!${NC}"
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Update the registry URL in the deployment manifests if needed"
    echo "2. Run ./scripts/deploy.sh to deploy to EKS"
}

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -r, --registry    Docker registry URL (default: your-registry)"
    echo "  -t, --tag         Image tag (default: latest)"
    echo "  -h, --help        Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DOCKER_REGISTRY   Docker registry URL"
    echo "  IMAGE_TAG         Docker image tag"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--registry)
            REGISTRY="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Execute main function
main "$@" 