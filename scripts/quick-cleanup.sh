#!/bin/bash

# Quick AWS Cleanup Script
# This is a simplified version that uses eksctl to delete everything

set -e

CLUSTER_NAME="solar-system-cluster"
REGION="us-west-2"

echo "🚨 QUICK AWS CLEANUP"
echo "==================="
echo "This will delete cluster: $CLUSTER_NAME in region: $REGION"
echo ""

# Safety check
read -p "Type 'yes' to confirm deletion: " confirm
if [ "$confirm" != "yes" ]; then
    echo "Cancelled"
    exit 0
fi

echo "🧹 Deleting Kubernetes resources first..."
# Clean up any LoadBalancers to avoid stuck deletion
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true
kubectl delete ingress --all --all-namespaces --ignore-not-found=true
kubectl delete namespace solar-system --ignore-not-found=true

echo "🗑️  Deleting EKS cluster with eksctl..."
eksctl delete cluster --name $CLUSTER_NAME --region $REGION --wait

echo "✅ Cleanup completed!"
echo "All resources deleted. Your AWS costs should stop accumulating."
