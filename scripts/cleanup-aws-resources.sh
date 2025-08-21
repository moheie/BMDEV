#!/bin/bash

# AWS Resource Cleanup Script
# This script will delete ALL AWS resources created for the Solar System project
# Use with caution - this will permanently delete your EKS cluster and all data

set -e

# Configuration
CLUSTER_NAME="solar-system-cluster"
REGION="us-west-2"
NODE_GROUP_NAME="solar-system-nodes"

# Check if timeout command is available, use a fallback if not
if command -v timeout &> /dev/null; then
    TIMEOUT_CMD="timeout"
else
    echo "⚠️  timeout command not available, some operations may hang"
    TIMEOUT_CMD=""
fi

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
        kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true
        
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
        if eksctl delete cluster --name $CLUSTER_NAME --region $REGION --wait; then
            echo "✅ Cluster and associated resources deleted with eksctl"
            return 0
        else
            echo "⚠️  eksctl delete failed, will proceed with manual cleanup"
            return 1
        fi
    else
        echo "ℹ️  Cluster not found in eksctl"
        return 1
    fi
}

# Function to cleanup stuck CloudFormation stacks
cleanup_stuck_cloudformation() {
    echo ""
    echo "🗑️  Checking for stuck CloudFormation stacks..."
    
    # Check for stuck CloudFormation stacks
    STUCK_STACKS=$(aws cloudformation list-stacks --region $REGION --query 'StackSummaries[?contains(StackName, `eksctl-'${CLUSTER_NAME}'`) && (StackStatus == `DELETE_FAILED` || StackStatus == `DELETE_IN_PROGRESS`)].StackName' --output text)
    
    if [ -n "$STUCK_STACKS" ]; then
        echo "📋 Found stuck CloudFormation stacks: $STUCK_STACKS"
        
        for stack in $STUCK_STACKS; do
            echo "🔍 Analyzing stack: $stack"
            
            # Check stack status
            STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $stack --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")
            
            if [ "$STACK_STATUS" = "DELETE_FAILED" ]; then
                echo "📋 Stack $stack is in DELETE_FAILED state, retrying deletion..."
                aws cloudformation delete-stack --stack-name $stack --region $REGION
                
                # Wait a bit for the deletion to start
                sleep 10
                STACK_STATUS=$(aws cloudformation describe-stacks --stack-name $stack --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "NOT_FOUND")
            fi
            
            if [ "$STACK_STATUS" = "DELETE_IN_PROGRESS" ]; then
                echo "⏳ Stack $stack is deleting, checking for blocking resources..."
                
                # Find VPC that might be blocking deletion
                VPC_ID=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=${stack}/VPC" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "None")
                
                if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
                    echo "📋 Found VPC blocking deletion: $VPC_ID"
                    cleanup_vpc_blocking_resources $VPC_ID
                fi
                
                # Wait for stack deletion with timeout
                echo "⏳ Waiting for stack deletion (max 10 minutes)..."
                if [ -n "$TIMEOUT_CMD" ]; then
                    $TIMEOUT_CMD 600 aws cloudformation wait stack-delete-complete --stack-name $stack --region $REGION || {
                        echo "⚠️  Stack deletion timed out, stack may still be deleting in background"
                    }
                else
                    # Fallback: check status periodically
                    for i in {1..20}; do
                        CURRENT_STATUS=$(aws cloudformation describe-stacks --stack-name $stack --region $REGION --query 'Stacks[0].StackStatus' --output text 2>/dev/null || echo "DELETED")
                        if [ "$CURRENT_STATUS" = "DELETED" ]; then
                            echo "✅ Stack deleted successfully"
                            break
                        elif [ "$CURRENT_STATUS" = "DELETE_FAILED" ]; then
                            echo "❌ Stack deletion failed"
                            break
                        fi
                        echo "   Still deleting... ($i/20)"
                        sleep 30
                    done
                fi
            fi
        done
    else
        echo "ℹ️  No stuck CloudFormation stacks found"
    fi
}

# Function to cleanup VPC resources that block CloudFormation deletion
cleanup_vpc_blocking_resources() {
    local VPC_ID=$1
    echo "🧹 Cleaning up blocking resources in VPC: $VPC_ID"
    
    # Delete security groups that might be blocking (except default)
    echo "📋 Checking for blocking security groups..."
    SG_IDS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text)
    
    for sg in $SG_IDS; do
        if [ "$sg" != "None" ] && [ -n "$sg" ]; then
            echo "📋 Attempting to delete security group: $sg"
            aws ec2 delete-security-group --group-id $sg --region $REGION 2>/dev/null && echo "✅ Deleted security group: $sg" || echo "⚠️  Could not delete security group: $sg (may have dependencies)"
        fi
    done
    
    # Delete network interfaces that might be attached
    echo "📋 Checking for network interfaces..."
    ENI_IDS=$(aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkInterfaces[?Status==`available`].NetworkInterfaceId' --output text)
    
    for eni in $ENI_IDS; do
        if [ "$eni" != "None" ] && [ -n "$eni" ]; then
            echo "📋 Attempting to delete network interface: $eni"
            aws ec2 delete-network-interface --network-interface-id $eni --region $REGION 2>/dev/null && echo "✅ Deleted network interface: $eni" || echo "⚠️  Could not delete network interface: $eni"
        fi
    done
    
    # Wait a moment for changes to propagate
    echo "⏳ Waiting for resource cleanup to propagate..."
    sleep 30
}
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
    EKSCTL_SUCCESS=false
    if delete_with_eksctl; then
        EKSCTL_SUCCESS=true
        echo "✅ eksctl deletion completed successfully"
    else
        echo "⚠️  eksctl deletion failed or cluster not found, proceeding with manual cleanup"
    fi
    
    # Step 3: Clean up stuck CloudFormation stacks
    cleanup_stuck_cloudformation
    
    # Step 4: If eksctl didn't work, try manual deletion
    if [ "$EKSCTL_SUCCESS" = false ]; then
        delete_node_groups
        delete_eks_cluster
    fi
    
    # Step 5: Clean up networking if still exists
    cleanup_networking
    
    # Step 6: Clean up IAM roles (optional - be careful)
    read -p "🔐 Do you want to delete IAM roles created by eksctl? (y/N): " delete_iam
    if [ "$delete_iam" = "y" ] || [ "$delete_iam" = "Y" ]; then
        cleanup_iam_roles
    else
        echo "ℹ️  Skipping IAM role cleanup"
    fi
    
    # Step 7: Final verification
    echo ""
    echo "🔍 Final verification..."
    
    # Check if cluster still exists
    if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION &> /dev/null; then
        echo "⚠️  EKS Cluster still exists"
    else
        echo "✅ EKS Cluster deleted"
    fi
    
    # Check for remaining CloudFormation stacks
    REMAINING_STACKS=$(aws cloudformation list-stacks --region $REGION --query 'StackSummaries[?contains(StackName, `eksctl-'${CLUSTER_NAME}'`) && StackStatus != `DELETE_COMPLETE`].StackName' --output text)
    if [ -n "$REMAINING_STACKS" ]; then
        echo "⚠️  Some CloudFormation stacks remain: $REMAINING_STACKS"
        echo "    These may still be deleting in the background"
    else
        echo "✅ All CloudFormation stacks deleted"
    fi
    
    # Check for remaining VPCs
    REMAINING_VPCS=$(aws ec2 describe-vpcs --region $REGION --filters "Name=tag:Name,Values=eksctl-${CLUSTER_NAME}-cluster/VPC" --query 'Vpcs[].VpcId' --output text)
    if [ -n "$REMAINING_VPCS" ] && [ "$REMAINING_VPCS" != "None" ]; then
        echo "⚠️  Some VPCs remain: $REMAINING_VPCS"
    else
        echo "✅ All VPCs and networking deleted"
    fi
    
    echo ""
    echo "🎉 CLEANUP PROCESS COMPLETED!"
    echo "============================"
    echo "✅ AWS resource cleanup has finished"
    echo "✅ Your AWS bill should no longer include charges for these resources"
    echo ""
    echo "📝 Resources that were processed:"
    echo "   - EKS Cluster: $CLUSTER_NAME"
    echo "   - Node Groups and EC2 instances"
    echo "   - LoadBalancers and networking"
    echo "   - VPC and associated networking components"
    echo "   - Security Groups"
    echo "   - CloudFormation stacks"
    if [ "$delete_iam" = "y" ] || [ "$delete_iam" = "Y" ]; then
        echo "   - IAM Roles created by eksctl"
    fi
    echo ""
    echo "⚠️  Important Notes:"
    echo "   - Some resources may take a few more minutes to be fully removed"
    echo "   - Check your AWS console to verify all resources are deleted"
    echo "   - If any resources remain, they may still be deleting in the background"
    echo "   - You can re-run this script to clean up any remaining resources"
    echo ""
    echo "🔍 To verify complete cleanup, you can run:"
    echo "   aws eks describe-cluster --name $CLUSTER_NAME --region $REGION"
    echo "   (Should return 'cluster not found' error when fully deleted)"
}

# Run the main function
main "$@"
