# Solar System EKS Deployment with Terraform

This directory contains Terraform configurations to deploy the Solar System application on AWS EKS (Elastic Kubernetes Service) with complete infrastructure as code.

## 🏗️ Architecture Overview

The Terraform configuration creates:

- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **EKS Cluster**: Managed Kubernetes cluster with logging enabled
- **Node Group**: Auto-scaling group of worker nodes
- **Security Groups**: Proper network security for cluster and nodes
- **IAM Roles**: Required roles and policies for EKS and nodes
- **Load Balancer**: AWS LoadBalancer for external access
- **Kubernetes Resources**: Namespace, deployment, and service for the app

## 📁 File Structure

```
terraform/
├── main.tf                    # Main Terraform configuration (VPC, subnets, networking)
├── variables.tf               # Variable definitions
├── eks.tf                     # EKS cluster and node group configuration
├── kubernetes.tf              # Kubernetes resources and providers
├── outputs.tf                 # Output values
├── locals.tf                  # Local values and computed references
├── backend.tf                 # Backend configuration (commented for local use)
├── terraform.tfvars.example   # Example variable values
└── terraform.tfvars          # Your actual variable values (created from example)
```

## 🚀 Quick Start

### Prerequisites

1. **Install Required Tools**:
   ```bash
   # Terraform
   choco install terraform  # Windows with Chocolatey
   # or download from https://www.terraform.io/downloads
   
   # AWS CLI
   choco install awscli     # Windows with Chocolatey
   # or download from https://aws.amazon.com/cli/
   
   # kubectl
   choco install kubernetes-cli  # Windows with Chocolatey
   # or download from https://kubernetes.io/docs/tasks/tools/
   ```

2. **Configure AWS Credentials**:
   ```bash
   aws configure
   # Enter your AWS Access Key ID, Secret Access Key, and region
   ```

### Deployment Options

#### Option 1: Using PowerShell Script (Recommended for Windows)
```powershell
# Deploy infrastructure and application
.\scripts\deploy-terraform.ps1

# Cleanup when done
.\scripts\cleanup-terraform.ps1
```

#### Option 2: Using Bash Script (Linux/macOS/Git Bash)
```bash
# Deploy infrastructure and application
./scripts/deploy-terraform.sh

# Cleanup when done
./scripts/cleanup-terraform.sh
```

#### Option 3: Manual Terraform Commands
```bash
# 1. Navigate to terraform directory
cd terraform

# 2. Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars as needed

# 3. Initialize Terraform
terraform init

# 4. Validate configuration
terraform validate

# 5. Plan deployment
terraform plan -var-file="terraform.tfvars"

# 6. Apply deployment
terraform apply -var-file="terraform.tfvars"

# 7. Configure kubectl
aws eks update-kubeconfig --region us-west-2 --name solar-system-cluster

# 8. Verify deployment
kubectl get pods -n solar-system
kubectl get svc -n solar-system
```

## ⚙️ Configuration

### Essential Variables

Edit `terraform.tfvars` to customize your deployment:

```hcl
# AWS Configuration
aws_region = "us-west-2"

# Project Configuration
project_name = "solar-system"
environment  = "development"

# EKS Cluster Configuration
cluster_name    = "solar-system-cluster"
cluster_version = "1.27"

# Node Group Configuration
node_group_instance_types   = ["t3.medium"]
node_group_desired_capacity = 2
node_group_max_capacity     = 4
node_group_min_capacity     = 1
```

### Advanced Configuration

For production environments, consider:

1. **Remote State Backend** (uncomment in `backend.tf`):
   ```hcl
   terraform {
     backend "s3" {
       bucket         = "your-terraform-state-bucket"
       key            = "solar-system/terraform.tfstate"
       region         = "us-west-2"
       encrypt        = true
       dynamodb_table = "terraform-state-lock"
     }
   }
   ```

2. **IAM User/Role Mapping**:
   ```hcl
   map_users = [
     {
       userarn  = "arn:aws:iam::123456789012:user/your-username"
       username = "your-username"
       groups   = ["system:masters"]
     }
   ]
   ```

## 🔧 Troubleshooting

### Common Issues

1. **Terraform Init Fails**:
   ```bash
   # Clear cache and reinitialize
   rm -rf .terraform
   terraform init
   ```

2. **AWS Credentials Issues**:
   ```bash
   # Verify credentials
   aws sts get-caller-identity
   
   # Reconfigure if needed
   aws configure
   ```

3. **kubectl Access Issues**:
   ```bash
   # Reconfigure kubectl
   aws eks update-kubeconfig --region us-west-2 --name solar-system-cluster
   
   # Verify access
   kubectl cluster-info
   ```

4. **LoadBalancer Not Getting External IP**:
   ```bash
   # Check LoadBalancer status
   kubectl describe svc solar-system-service -n solar-system
   
   # Wait for provisioning (can take 5-10 minutes)
   kubectl get svc -n solar-system -w
   ```

### State File Issues

If you encounter state file corruption:

```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Import existing resources (example for VPC)
terraform import aws_vpc.main vpc-xxxxxxxxx

# Refresh state
terraform refresh
```

## 💰 Cost Management

### Estimated Monthly Costs (us-west-2)

- **EKS Cluster**: $72.00/month (control plane)
- **t3.medium nodes (2)**: ~$60.00/month
- **LoadBalancer**: ~$18.00/month
- **NAT Gateways (2)**: ~$90.00/month
- **Storage & Data Transfer**: ~$10.00/month

**Total**: ~$250/month

### Cost Optimization Tips

1. **Use Spot Instances**:
   ```hcl
   capacity_type = "SPOT"
   ```

2. **Single NAT Gateway**:
   ```hcl
   # Use only one NAT gateway (less HA but cheaper)
   public_subnet_cidrs = ["10.0.1.0/24"]
   ```

3. **Smaller Instances**:
   ```hcl
   node_group_instance_types = ["t3.small"]
   ```

## 📊 Monitoring & Management

### Useful Commands

```bash
# Check cluster status
kubectl cluster-info

# View all resources
kubectl get all -A

# Check node status
kubectl get nodes

# View application logs
kubectl logs -f deployment/solar-system -n solar-system

# Scale application
kubectl scale deployment solar-system --replicas=5 -n solar-system

# Update application image
kubectl set image deployment/solar-system solar-system=moheie/solar-system:v2.0 -n solar-system
```

### AWS Console Access

Monitor your infrastructure via AWS Console:
- **EKS**: https://console.aws.amazon.com/eks/
- **EC2**: https://console.aws.amazon.com/ec2/
- **VPC**: https://console.aws.amazon.com/vpc/
- **IAM**: https://console.aws.amazon.com/iam/

## 🔄 CI/CD Integration

This Terraform configuration integrates with:

1. **Azure Pipelines**: `azure-pipelines-terraform.yml`
2. **GitHub Actions**: Can be adapted for GitHub workflows
3. **Local Development**: Manual deployment scripts

### Azure DevOps Setup

1. Create service connections for:
   - AWS (for Terraform and kubectl)
   - Docker Hub (for image pulls)

2. Update variable groups with:
   - AWS credentials
   - Terraform workspace settings

## 🧹 Cleanup

**Important**: Always clean up resources to avoid charges!

### Automated Cleanup
```powershell
# PowerShell
.\scripts\cleanup-terraform.ps1

# Bash
./scripts/cleanup-terraform.sh
```

### Manual Cleanup
```bash
cd terraform
terraform destroy -var-file="terraform.tfvars"
```

### Verification
After cleanup, verify no resources remain:
```bash
# Check EKS clusters
aws eks list-clusters --region us-west-2

# Check VPCs
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=solar-system" --region us-west-2
```

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)

## 🆘 Support

If you encounter issues:

1. Check the [troubleshooting section](#troubleshooting)
2. Review Terraform and kubectl logs
3. Verify AWS credentials and permissions
4. Check AWS service quotas and limits

For additional help, please create an issue with:
- Error messages
- Terraform version
- AWS CLI version
- kubectl version
- AWS region being used
