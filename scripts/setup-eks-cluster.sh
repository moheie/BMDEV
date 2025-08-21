#!/bin/bash

# Script to set up EKS cluster for Solar System application
set -e

# Configuration
CLUSTER_NAME="solar-system-cluster"
REGION="us-west-2"
NODE_TYPE="t3.medium"
MIN_NODES=1
MAX_NODES=4
DESIRED_NODES=2

echo "🚀 Setting up EKS cluster for Solar System application..."

# Check if eksctl is installed
if ! command -v eksctl &> /dev/null; then
    echo "❌ eksctl is not installed. Please install it first:"
    echo "https://eksctl.io/introduction/#installation"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed. Please install it first:"
    echo "https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure'"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Create EKS cluster
echo "📦 Creating EKS cluster: $CLUSTER_NAME"

# Check if SSH key exists
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"
if [ -f "$SSH_KEY_PATH" ]; then
    echo "✅ SSH key found, enabling SSH access to nodes"
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $REGION \
        --nodegroup-name ${CLUSTER_NAME}-nodes \
        --node-type $NODE_TYPE \
        --nodes $DESIRED_NODES \
        --nodes-min $MIN_NODES \
        --nodes-max $MAX_NODES \
        --managed \
        --with-oidc \
        --ssh-access \
        --ssh-public-key $SSH_KEY_PATH
else
    echo "⚠️  No SSH key found at $SSH_KEY_PATH, creating cluster without SSH access"
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $REGION \
        --nodegroup-name ${CLUSTER_NAME}-nodes \
        --node-type $NODE_TYPE \
        --nodes $DESIRED_NODES \
        --nodes-min $MIN_NODES \
        --nodes-max $MAX_NODES \
        --managed \
        --with-oidc
fi

echo "✅ EKS cluster created successfully!"

# Update kubeconfig
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Verify cluster
echo "🔍 Verifying cluster setup..."
kubectl get nodes
kubectl get namespaces

# Note: AWS Load Balancer Controller installation skipped
# The EKS cluster works fine with standard LoadBalancer service type
echo "ℹ️  Using standard LoadBalancer service (AWS Classic ELB)"
echo "ℹ️  ALB Ingress Controller can be installed separately if needed"

echo ""
echo "🎉 EKS cluster setup completed successfully!"
echo ""
echo "📋 Cluster Information:"
echo "  Name: $CLUSTER_NAME"
echo "  Region: $REGION"
echo "  Nodes: $DESIRED_NODES (min: $MIN_NODES, max: $MAX_NODES)"
echo ""
echo "🔧 Next steps:"
echo "  1. Configure Azure Pipeline variables"
echo "  2. Run the Azure Pipeline CD deployment"
echo "  3. Access your application via the LoadBalancer URL"
echo ""
echo "📚 Useful commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods --all-namespaces"
echo "  kubectl cluster-info"
