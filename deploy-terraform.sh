#!/bin/bash

# Terraform Deployment Script for Solar System EKS Cluster
# This script will deploy the complete infrastructure using Terraform

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
        print_error "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    
    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI first."
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_message "All prerequisites met ✅"
}

# Function to create terraform.tfvars if it doesn't exist
create_tfvars() {
    if [ ! -f "$TERRAFORM_DIR/$TFVARS_FILE" ]; then
        print_warning "terraform.tfvars not found. Creating from example..."
        cp "$TERRAFORM_DIR/terraform.tfvars.example" "$TERRAFORM_DIR/$TFVARS_FILE"
        print_message "Created $TFVARS_FILE from example. Please review and modify if needed."
    else
        print_message "Using existing $TFVARS_FILE"
    fi
}

# Function to initialize Terraform
terraform_init() {
    print_header "Initializing Terraform"
    cd "$TERRAFORM_DIR"
    terraform init
    print_message "Terraform initialized successfully ✅"
}

# Function to validate Terraform configuration
terraform_validate() {
    print_header "Validating Terraform Configuration"
    terraform validate
    print_message "Terraform configuration is valid ✅"
}

# Function to plan Terraform deployment
terraform_plan() {
    print_header "Planning Terraform Deployment"
    terraform plan -var-file="$TFVARS_FILE" -out=tfplan
    print_message "Terraform plan completed successfully ✅"
}

# Function to apply Terraform deployment
terraform_apply() {
    print_header "Applying Terraform Deployment"
    
    echo ""
    print_warning "This will create AWS resources that may incur costs."
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        terraform apply tfplan
        print_message "Infrastructure deployed successfully ✅"
    else
        print_message "Deployment cancelled by user."
        exit 0
    fi
}

# Function to configure kubectl
configure_kubectl() {
    print_header "Configuring kubectl"
    
    # Get cluster name and region from Terraform outputs
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    AWS_REGION=$(terraform output -raw aws_region)
    
    # Update kubeconfig
    aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"
    print_message "kubectl configured successfully ✅"
    
    # Verify cluster connection
    print_message "Verifying cluster connection..."
    kubectl cluster-info
    print_message "Cluster connection verified ✅"
}

# Function to wait for application to be ready
wait_for_application() {
    print_header "Waiting for Application to be Ready"
    
    print_message "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=solar-system -n solar-system --timeout=300s
    
    print_message "Waiting for LoadBalancer to be provisioned..."
    kubectl wait --for=jsonpath='{.status.loadBalancer.ingress}' service/solar-system-service -n solar-system --timeout=300s
    
    print_message "Application is ready ✅"
}

# Function to display access information
display_access_info() {
    print_header "Application Access Information"
    
    # Get LoadBalancer URL
    LB_URL=$(kubectl get svc solar-system-service -n solar-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    
    if [ -n "$LB_URL" ]; then
        print_message "🌟 Solar System Application is accessible at:"
        echo -e "   ${BLUE}http://$LB_URL${NC}"
        echo ""
        print_message "📊 Useful commands:"
        echo "   kubectl get pods -n solar-system          # Check pod status"
        echo "   kubectl get svc -n solar-system           # Check service status"
        echo "   kubectl logs -f deployment/solar-system -n solar-system  # View logs"
        echo "   kubectl describe deployment solar-system -n solar-system # Deployment details"
    else
        print_warning "LoadBalancer URL not yet available. Run the following command to check:"
        echo "   kubectl get svc -n solar-system"
    fi
}

# Function to show Terraform outputs
show_terraform_outputs() {
    print_header "Terraform Outputs"
    terraform output
}

# Main execution
main() {
    print_header "Solar System EKS Deployment with Terraform"
    
    # Check if we're in the right directory
    if [ ! -d "$TERRAFORM_DIR" ]; then
        print_error "Terraform directory not found. Please run this script from the project root."
        exit 1
    fi
    
    check_prerequisites
    create_tfvars
    terraform_init
    terraform_validate
    terraform_plan
    terraform_apply
    configure_kubectl
    wait_for_application
    display_access_info
    show_terraform_outputs
    
    print_header "Deployment Complete! 🎉"
    print_message "Your Solar System application is now running on AWS EKS!"
    print_message "Don't forget to run the cleanup script when you're done to avoid charges."
}

# Handle script interruption
trap 'print_error "Script interrupted by user"; exit 1' INT

# Run main function
main "$@"
