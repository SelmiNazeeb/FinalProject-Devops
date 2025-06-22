#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# --- Configuration ---
CLUSTER_NAME="three-tier-eks-cluster"
REGION="us-west-2"
ACCOUNT_ID="626072240565"
POLICY_NAME="AWSLoadBalancerControllerIAMPolicy4"
ROLE_NAME="AmazonEKSLoadBalancerControllerRole4"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"
CLUSTER="my-cluster"

echo "=== Step 1: Download IAM policy JSON for AWS Load Balancer Controller ==="
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json

echo "=== Step 1.1: Inject additional permission into the policy ==="
# Add 'elasticloadbalancing:DescribeListenerAttributes' if not already present
jq '.Statement[0].Action += ["elasticloadbalancing:DescribeListenerAttributes"]' iam_policy.json > iam_policy_updated.json

echo "=== Step 2: Create IAM policy ==="
aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://iam_policy_updated.json || echo "Policy may already exist"

echo "=== Step 3: Associate IAM OIDC Provider with the cluster ==="
eksctl utils associate-iam-oidc-provider \
  --region=$REGION \
  --cluster=$CLUSTER_NAME \
  --approve

echo "=== Step 4: Create IAM service account for ALB Controller ==="
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=$NAMESPACE \
  --name=$SERVICE_ACCOUNT_NAME \
  --role-name $ROLE_NAME \
  --attach-policy-arn=arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME} \
  --approve \
  --region=$REGION

echo "=== Step 5: Install Helm (if not already installed) ==="
if ! command -v helm &> /dev/null; then
  curl https://baltocdn.com/helm/signing.asc | gpg --dearmor > /usr/share/keyrings/helm.gpg
  apt-get update && apt-get install -y apt-transport-https curl
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" > /etc/apt/sources.list.d/helm-stable-debian.list
  apt-get update && apt-get install -y helm
else
  echo "Helm already installed"
fi

echo "=== Step 6: Add and update EKS Helm chart repository ==="
helm repo add eks https://aws.github.io/eks-charts
helm repo update

echo "=== Step 7: Deploy AWS Load Balancer Controller ==="
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n $NAMESPACE \
  --set clusterName=$CLUSTER \
  --set serviceAccount.create=false \
  --set serviceAccount.name=$SERVICE_ACCOUNT_NAME \
  --set region=$REGION \
  --set vpcId=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION --query "cluster.resourcesVpcConfig.vpcId" --output text)

echo "=== Step 8: Validate deployment ==="
kubectl get deployment -n $NAMESPACE aws-load-balancer-controller
