#!/bin/bash

# CloudOps Demo - Deployment Script for EKS
# This script deploys the three-tier application to AWS EKS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-"cloudops-demo"}
REGION=${AWS_REGION:-"us-west-2"}
NAMESPACE="cloudops-demo"

echo -e "${BLUE}🚀 Starting CloudOps Demo Deployment${NC}"
echo "================================="

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}📋 Checking prerequisites...${NC}"

    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl is not installed${NC}"
        exit 1
    fi

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo -e "${RED}❌ AWS CLI is not installed${NC}"
        exit 1
    fi

    # Check if eksctl is installed
    if ! command -v eksctl &> /dev/null; then
        echo -e "${RED}❌ eksctl is not installed${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ All prerequisites are met${NC}"
}

# Create EKS cluster if it doesn't exist
create_cluster() {
    echo -e "${YELLOW}🏗️  Checking EKS cluster...${NC}"

    if ! eksctl get cluster --name=$CLUSTER_NAME --region=$REGION >/dev/null 2>&1; then
        echo -e "${YELLOW}Creating EKS cluster: $CLUSTER_NAME${NC}"
        eksctl create cluster \
            --name=$CLUSTER_NAME \
            --region=$REGION \
            --nodes=3 \
            --node-type=t3.medium \
            --with-oidc \
            --ssh-access \
            --ssh-public-key=~/.ssh/id_rsa.pub \
            --managed
        echo -e "${GREEN}✅ EKS cluster created successfully${NC}"
    else
        echo -e "${GREEN}✅ EKS cluster already exists${NC}"
    fi

    # Update kubeconfig
    aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME
}

# Install AWS Load Balancer Controller
install_alb_controller() {
    echo -e "${YELLOW}🔧 Installing AWS Load Balancer Controller...${NC}"

    # Download IAM policy
    curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json

    # Create IAM policy
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file://iam_policy.json || true

    # Create IAM role and service account
    eksctl create iamserviceaccount \
        --cluster=$CLUSTER_NAME \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --role-name "AmazonEKSLoadBalancerControllerRole" \
        --attach-policy-arn=arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/AWSLoadBalancerControllerIAMPolicy \
        --approve || true

    # Install the controller using Helm
    helm repo add eks https://aws.github.io/eks-charts || true
    helm repo update
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller || true

    echo -e "${GREEN}✅ AWS Load Balancer Controller installed${NC}"

    # Clean up
    rm -f iam_policy.json
}

# Deploy application to Kubernetes
deploy_application() {
    echo -e "${YELLOW}🚀 Deploying application to Kubernetes...${NC}"

    # Apply all Kubernetes manifests
    kubectl apply -f k8s/

    echo -e "${GREEN}✅ Application deployed successfully${NC}"

    # Wait for deployments to be ready
    echo -e "${YELLOW}⏳ Waiting for deployments to be ready...${NC}"
    kubectl wait --for=condition=available --timeout=300s deployment/backend-deployment -n $NAMESPACE
    kubectl wait --for=condition=available --timeout=300s deployment/frontend-deployment -n $NAMESPACE

    echo -e "${GREEN}✅ All deployments are ready${NC}"
}

# Display application information
show_info() {
    echo -e "${BLUE}📊 Application Information${NC}"
    echo "================================="

    # Get LoadBalancer URL
    LOAD_BALANCER_URL=$(kubectl get service frontend-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

    if [ ! -z "$LOAD_BALANCER_URL" ]; then
        echo -e "${GREEN}🌐 Application URL: http://$LOAD_BALANCER_URL${NC}"
    else
        echo -e "${YELLOW}⏳ LoadBalancer is being provisioned. Check again in a few minutes.${NC}"
    fi

    # Show pod status
    echo -e "\n${YELLOW}Pod Status:${NC}"
    kubectl get pods -n $NAMESPACE

    # Show services
    echo -e "\n${YELLOW}Services:${NC}"
    kubectl get services -n $NAMESPACE
}

# Main execution
main() {
    check_prerequisites
    create_cluster
    install_alb_controller
    deploy_application
    show_info

    echo -e "\n${GREEN}🎉 Deployment completed successfully!${NC}"
    echo -e "${BLUE}To monitor your application:${NC}"
    echo "kubectl get all -n $NAMESPACE"
    echo "kubectl logs -f deployment/backend-deployment -n $NAMESPACE"
}

# Execute main function
main "$@"