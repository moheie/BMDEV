#!/bin/bash

# Terraform Cleanup Script for Solar System EKS Cluster
# This script will destroy all AWS resources created by Terraform

set -e

# Configuration
TERRAFORM_DIR="./terraform"
TFVARS_FILE="terraform.tfvars"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured."
        exit 1
    fi
    
    # Check if Terraform is initialized
    if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
        print_error "Terraform not initialized. Please run deploy-terraform.sh first or run 'terraform init' manually."
        exit 1
    fi
    
    print_message "All prerequisites met ✅"
}

# Function to check current infrastructure
check_infrastructure() {
    print_header "Checking Current Infrastructure"
    cd "$TERRAFORM_DIR"
    
    # Check if state file exists
    if [ ! -f "terraform.tfstate" ] && [ ! -f ".terraform/terraform.tfstate" ]; then
        print_warning "No Terraform state found. Infrastructure may already be destroyed or was created manually."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_message "Cleanup cancelled by user."
            exit 0
        fi
    fi
    
    # Show current resources
    print_message "Current infrastructure:"
    terraform show -no-color | head -20
    echo "..."
}

# Function to plan Terraform destroy
terraform_plan_destroy() {
    print_header "Planning Infrastructure Destruction"
    terraform plan -destroy -var-file="$TFVARS_FILE" -out=destroy-plan
    print_message "Terraform destroy plan completed ✅"
}

# Function to destroy infrastructure
terraform_destroy() {
    print_header "Destroying Infrastructure"
    
    echo ""
    print_warning "⚠️  WARNING: This will PERMANENTLY DELETE all AWS resources created by Terraform!"
    print_warning "This includes:"
    echo "   • EKS Cluster and all workloads"
    echo "   • VPC, subnets, and networking components"
    echo "   • Security groups and IAM roles"
    echo "   • Load balancers and any attached resources"
    echo "   • All data and configurations"
    echo ""
    print_warning "This action CANNOT be undone!"
    echo ""
    
    read -p "Are you absolutely sure you want to destroy ALL resources? Type 'DESTROY' to confirm: " -r
    echo ""
    
    if [[ $REPLY == "DESTROY" ]]; then
        print_message "Starting infrastructure destruction..."
        terraform apply destroy-plan
        print_message "Infrastructure destroyed successfully ✅"
    else
        print_message "Destruction cancelled by user."
        exit 0
    fi
}

# Function to cleanup kubectl configuration
cleanup_kubectl() {
    print_header "Cleaning up kubectl Configuration"
    
    # Get cluster name from Terraform outputs (if still available)
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "solar-system-cluster")
    
    # Remove cluster from kubeconfig
    kubectl config delete-cluster "$CLUSTER_NAME" 2>/dev/null || true
    kubectl config delete-context "$CLUSTER_NAME" 2>/dev/null || true
    
    print_message "kubectl configuration cleaned up ✅"
}

# Function to cleanup local files
cleanup_local_files() {
    print_header "Cleaning up Local Files"
    
    # Remove Terraform plan files
    rm -f tfplan destroy-plan
    
    # Optionally remove terraform.tfvars (ask user)
    if [ -f "$TFVARS_FILE" ]; then
        echo ""
        read -p "Remove terraform.tfvars file? (y/N): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$TFVARS_FILE"
            print_message "terraform.tfvars removed"
        else
            print_message "terraform.tfvars preserved"
        fi
    fi
    
    print_message "Local cleanup completed ✅"
}

# Function to verify cleanup
verify_cleanup() {
    print_header "Verifying Cleanup"
    
    # Check for any remaining resources (this will show errors if resources are gone, which is good)
    print_message "Checking for remaining AWS resources..."
    
    # Try to describe the EKS cluster
    CLUSTER_NAME="solar-system-cluster"
    aws eks describe-cluster --name "$CLUSTER_NAME" --region us-west-2 &>/dev/null && {
        print_warning "EKS cluster still exists!"
    } || {
        print_message "✅ EKS cluster successfully removed"
    }
    
    # Check for VPC
    VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=solar-system-vpc" --query 'Vpcs[0].VpcId' --output text --region us-west-2 2>/dev/null || echo "None")
    if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "null" ]; then
        print_warning "VPC still exists: $VPC_ID"
    else
        print_message "✅ VPC successfully removed"
    fi
    
    print_message "Cleanup verification completed"
}

# Function to show final status
show_final_status() {
    print_header "Cleanup Summary"
    
    echo -e "${GREEN}✅ Infrastructure Cleanup Complete!${NC}"
    echo ""
    print_message "What was cleaned up:"
    echo "   • EKS cluster and all workloads"
    echo "   • VPC and networking components"
    echo "   • Security groups and IAM roles"
    echo "   • Load balancers"
    echo "   • kubectl configuration"
    echo "   • Local Terraform plan files"
    echo ""
    print_message "Your AWS account should no longer have Solar System resources."
    print_message "You can verify this in the AWS Console or by running AWS CLI commands."
    echo ""
    print_warning "If you see any remaining resources, they may need manual cleanup."
}

# Main execution
main() {
    print_header "Solar System Infrastructure Cleanup"
    
    # Check if we're in the right directory
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found. Please run this script from the project root."
        exit 1
    fi
    
    check_prerequisites
    check_infrastructure
    terraform_plan_destroy
    terraform_destroy
    cleanup_kubectl
    cleanup_local_files
    verify_cleanup
    show_final_status
    
    print_header "All Done! 🧹"
}

# Handle script interruption
trap 'print_error "Script interrupted by user"; exit 1' INT

# Run main function
main "$@"
