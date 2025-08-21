#!/bin/bash

# AWS Resource Cleanup Script
# This script will delete ALL AWS resources created for the Solar System project
# Use with caution - this will permanently delete your EKS cluster and all data

set -e

# Configuration
CLUSTER_NAME="solar-system-cluster"
REGION="us-west-2"
NODE_GROUP_NAME="solar-system-nodes"

echo "🚨 AWS RESOURCE CLEANUP SCRIPT 🚨"
echo "=================================="
echo "This will DELETE the following resources:"
echo "- EKS Cluster: $CLUSTER_NAME"
echo "- Node Groups: $NODE_GROUP_NAME"
echo "- VPC and networking components"
echo "- Security Groups"
echo "- IAM Roles (if created by eksctl)"
echo "- LoadBalancers and associated resources"
echo ""

# Safety confirmation
read -p "⚠️  Are you ABSOLUTELY SURE you want to delete ALL resources? (type 'DELETE' to confirm): " confirmation
if [ "$confirmation" != "DELETE" ]; then
    echo "❌ Cleanup cancelled. No resources were deleted."
    exit 0
fi

echo ""
echo "🗑️  Starting AWS resource cleanup..."
echo "=================================="

# Function to check if AWS CLI is configured
check_aws_cli() {
    echo "🔍 Checking AWS CLI configuration..."
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        echo "❌ AWS CLI is not configured or credentials are invalid"
        echo "Please run 'aws configure' first"
        exit 1
    fi
    echo "✅ AWS CLI is configured"
}

# Function to check if eksctl is installed
check_eksctl() {
    echo "🔍 Checking eksctl installation..."
    if ! command -v eksctl &> /dev/null; then
        echo "❌ eksctl is not installed"
        echo "Please install eksctl first"
        exit 1
    fi
    echo "✅ eksctl is available"
}

# Function to delete Kubernetes resources first
cleanup_kubernetes_resources() {
    echo ""
    echo "🧹 Cleaning up Kubernetes resources..."
    
    # Check if cluster is accessible
    if kubectl cluster-info &> /dev/null; then
        echo "📋 Deleting all resources in solar-system namespace..."
        kubectl delete all --all -n solar-system --ignore-not-found=true
        
        echo "📋 Deleting solar-system namespace..."
        kubectl delete namespace solar-system --ignore-not-found=true
        
        echo "📋 Deleting any remaining LoadBalancers..."
        kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true
        
        echo "📋 Deleting any remaining ingresses..."
        kubectl delete ingress --all --all-namespaces --ignore-not-found=true
        
        echo "⏳ Waiting 30 seconds for LoadBalancers to be cleaned up..."
        sleep 30
        
        echo "✅ Kubernetes resources cleaned up"
    else
        echo "⚠️  Cannot connect to cluster - it may already be deleted"
    fi
}

# Function to delete EKS node groups
delete_node_groups() {
    echo ""
    echo "🗑️  Deleting EKS node groups..."
    
    # Get all node groups for the cluster
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups[]' --output text 2>/dev/null || echo "")
    
    if [ -n "$NODE_GROUPS" ]; then
        for nodegroup in $NODE_GROUPS; do
            echo "📋 Deleting node group: $nodegroup"
            aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $REGION
        done
        
        echo "⏳ Waiting for node groups to be deleted..."
        for nodegroup in $NODE_GROUPS; do
            aws eks wait nodegroup-deleted --cluster-name $CLUSTER_NAME --nodegroup-name $nodegroup --region $REGION
            echo "✅ Node group $nodegroup deleted"
        done
    else
        echo "ℹ️  No node groups found or cluster doesn't exist"
    fi
}

# Function to delete EKS cluster
delete_eks_cluster() {
    echo ""
    echo "🗑️  Deleting EKS cluster..."
    
    # Check if cluster exists
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        echo "📋 Deleting cluster: $CLUSTER_NAME"
        aws eks delete-cluster --name $CLUSTER_NAME --region $REGION
        
        echo "⏳ Waiting for cluster to be deleted (this may take 10-15 minutes)..."
        aws eks wait cluster-deleted --name $CLUSTER_NAME --region $REGION
        echo "✅ EKS cluster deleted"
    else
        echo "ℹ️  Cluster $CLUSTER_NAME not found - it may already be deleted"
    fi
}

# Function to delete using eksctl (alternative method)
delete_with_eksctl() {
    echo ""
    echo "🗑️  Using eksctl to delete cluster and associated resources..."
    
    # Check if cluster exists in eksctl
    if eksctl get cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        echo "📋 Deleting cluster with eksctl (this will also delete VPC, security groups, etc.)"
        eksctl delete cluster --name $CLUSTER_NAME --region $REGION --wait
        echo "✅ Cluster and associated resources deleted with eksctl"
    else
        echo "ℹ️  Cluster not found in eksctl"
    fi
}

# Function to delete VPC and networking (if not deleted by eksctl)
cleanup_networking() {
    echo ""
    echo "🗑️  Cleaning up remaining networking resources..."
    
    # Find VPC tagged with cluster name
    VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=eksctl-${CLUSTER_NAME}-cluster/VPC" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
    
    if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
        echo "📋 Found VPC: $VPC_ID"
        
        # Delete NAT Gateways
        echo "📋 Deleting NAT Gateways..."
        NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" --query 'NatGateways[?State==`available`].NatGatewayId' --output text)
        for nat in $NAT_GATEWAYS; do
            if [ "$nat" != "None" ]; then
                aws ec2 delete-nat-gateway --nat-gateway-id $nat --region $REGION
                echo "📋 Deleted NAT Gateway: $nat"
            fi
        done
        
        # Release Elastic IPs
        echo "📋 Releasing Elastic IPs..."
        ALLOCATION_IDS=$(aws ec2 describe-addresses --region $REGION --filters "Name=domain,Values=vpc" --query 'Addresses[?AssociationId==null].AllocationId' --output text)
        for alloc in $ALLOCATION_IDS; do
            if [ "$alloc" != "None" ]; then
                aws ec2 release-address --allocation-id $alloc --region $REGION 2>/dev/null || true
                echo "📋 Released Elastic IP: $alloc"
            fi
        done
        
        # Delete Internet Gateway
        echo "📋 Deleting Internet Gateways..."
        IGW_IDS=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text)
        for igw in $IGW_IDS; do
            if [ "$igw" != "None" ]; then
                aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $VPC_ID --region $REGION
                aws ec2 delete-internet-gateway --internet-gateway-id $igw --region $REGION
                echo "📋 Deleted Internet Gateway: $igw"
            fi
        done
        
        # Delete Subnets
        echo "📋 Deleting Subnets..."
        SUBNET_IDS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text)
        for subnet in $SUBNET_IDS; do
            if [ "$subnet" != "None" ]; then
                aws ec2 delete-subnet --subnet-id $subnet --region $REGION
                echo "📋 Deleted Subnet: $subnet"
            fi
        done
        
        # Delete Route Tables
        echo "📋 Deleting Route Tables..."
        ROUTE_TABLE_IDS=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=false" --query 'RouteTables[].RouteTableId' --output text)
        for rt in $ROUTE_TABLE_IDS; do
            if [ "$rt" != "None" ]; then
                aws ec2 delete-route-table --route-table-id $rt --region $REGION
                echo "📋 Deleted Route Table: $rt"
            fi
        done
        
        # Delete Security Groups (except default)
        echo "📋 Deleting Security Groups..."
        SG_IDS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
        for sg in $SG_IDS; do
            if [ "$sg" != "None" ]; then
                aws ec2 delete-security-group --group-id $sg --region $REGION 2>/dev/null || true
                echo "📋 Deleted Security Group: $sg"
            fi
        done
        
        # Finally delete VPC
        echo "📋 Deleting VPC: $VPC_ID"
        aws ec2 delete-vpc --vpc-id $VPC_ID --region $REGION
        echo "✅ VPC deleted"
    else
        echo "ℹ️  No VPC found for cleanup"
    fi
}

# Function to cleanup IAM roles (be careful with this)
cleanup_iam_roles() {
    echo ""
    echo "🗑️  Cleaning up IAM roles (if created by eksctl)..."
    
    # List and delete cluster service role
    CLUSTER_ROLE="eksctl-${CLUSTER_NAME}-cluster-ServiceRole-*"
    aws iam list-roles --query "Roles[?starts_with(RoleName, 'eksctl-${CLUSTER_NAME}-cluster-ServiceRole')].RoleName" --output text | while read role; do
        if [ "$role" != "None" ] && [ -n "$role" ]; then
            echo "📋 Detaching policies from role: $role"
            aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text | while read policy; do
                aws iam detach-role-policy --role-name "$role" --policy-arn "$policy"
            done
            echo "📋 Deleting role: $role"
            aws iam delete-role --role-name "$role"
        fi
    done
    
    # List and delete node group roles
    NODE_ROLE="eksctl-${CLUSTER_NAME}-nodegroup-*"
    aws iam list-roles --query "Roles[?starts_with(RoleName, 'eksctl-${CLUSTER_NAME}-nodegroup')].RoleName" --output text | while read role; do
        if [ "$role" != "None" ] && [ -n "$role" ]; then
            echo "📋 Detaching policies from role: $role"
            aws iam list-attached-role-policies --role-name "$role" --query 'AttachedPolicies[].PolicyArn' --output text | while read policy; do
                aws iam detach-role-policy --role-name "$role" --policy-arn "$policy"
            done
            echo "📋 Deleting role: $role"
            aws iam delete-role --role-name "$role"
        fi
    done
    
    echo "✅ IAM roles cleanup completed"
}

# Main execution
main() {
    echo "🚀 Starting cleanup process..."
    
    # Pre-flight checks
    check_aws_cli
    check_eksctl
    
    # Step 1: Clean up Kubernetes resources
    cleanup_kubernetes_resources
    
    # Step 2: Try eksctl delete first (recommended)
    delete_with_eksctl
    
    # Step 3: If eksctl didn't work, try manual deletion
    delete_node_groups
    delete_eks_cluster
    
    # Step 4: Clean up networking if still exists
    cleanup_networking
    
    # Step 5: Clean up IAM roles (optional - be careful)
    read -p "🔐 Do you want to delete IAM roles created by eksctl? (y/N): " delete_iam
    if [ "$delete_iam" = "y" ] || [ "$delete_iam" = "Y" ]; then
        cleanup_iam_roles
    else
        echo "ℹ️  Skipping IAM role cleanup"
    fi
    
    echo ""
    echo "🎉 CLEANUP COMPLETED!"
    echo "==================="
    echo "✅ All AWS resources have been deleted"
    echo "✅ Your AWS bill should no longer include these resources"
    echo ""
    echo "📝 Resources that were deleted:"
    echo "   - EKS Cluster: $CLUSTER_NAME"
    echo "   - Node Groups and EC2 instances"
    echo "   - LoadBalancers and networking"
    echo "   - VPC and associated networking components"
    echo "   - Security Groups"
    if [ "$delete_iam" = "y" ] || [ "$delete_iam" = "Y" ]; then
        echo "   - IAM Roles created by eksctl"
    fi
    echo ""
    echo "⚠️  Note: It may take a few minutes for all resources to be fully"
    echo "   removed from your AWS console and billing."
}

# Run the main function
main "$@"
