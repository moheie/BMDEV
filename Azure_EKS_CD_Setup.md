# Azure Pipelines CD Setup for AWS EKS Deployment

## Overview
This document provides instructions for setting up a Continuous Deployment (CD) pipeline using Azure Pipelines to deploy the Solar System application to an AWS EKS cluster.

## Prerequisites

### 1. AWS EKS Cluster
Ensure you have an EKS cluster running:

```bash
# Create EKS cluster (if not exists)
eksctl create cluster \
  --name solar-system-cluster \
  --region us-west-2 \
  --nodegroup-name solar-system-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 4 \
  --managed

# Verify cluster
kubectl get nodes
```

### 2. AWS Credentials
Create an IAM user with the following permissions:
- `AmazonEKSClusterPolicy`
- `AmazonEKSWorkerNodePolicy` 
- `AmazonEKS_CNI_Policy`
- `AmazonEC2ContainerRegistryReadOnly`

### 3. Azure DevOps Project
- Create a new Azure DevOps project
- Connect your GitHub repository

## Setup Instructions

### Step 1: Configure Azure Pipeline Variables

In your Azure DevOps project, navigate to **Pipelines** → **Library** → **Variable Groups** and create a new variable group called `aws-eks-deployment` with the following variables:

#### Required Variables:
| Variable Name | Value | Secret |
|---------------|-------|---------|
| `AWS_ACCESS_KEY_ID` | Your AWS Access Key ID | ✅ |
| `AWS_SECRET_ACCESS_KEY` | Your AWS Secret Access Key | ✅ |
| `AWS_REGION` | us-west-2 (or your preferred region) | ❌ |
| `EKS_CLUSTER_NAME` | solar-system-cluster | ❌ |
| `DOCKERHUB_USERNAME` | Your Docker Hub username | ❌ |

### Step 2: Create Pipeline

1. In Azure DevOps, go to **Pipelines** → **New Pipeline**
2. Select **GitHub** as your repository source
3. Choose **Existing Azure Pipelines YAML file**
4. Select the path: `/azure-pipelines-cd.yml`
5. Review and run the pipeline

### Step 3: Pipeline Structure

The pipeline includes the following stages:

#### Tools Installation
- AWS CLI v2
- kubectl
- Python 3.x

#### AWS Configuration
- Configure AWS credentials
- Update kubeconfig for EKS cluster
- Verify cluster connectivity

#### Deployment
- Update Kubernetes manifests with Docker image
- Deploy application, service, and ingress
- Wait for deployment rollout
- Perform health checks

#### Verification
- Get service endpoints
- Display deployment summary
- Verify application accessibility

## Kubernetes Manifests

### Deployment (`k8s/deployment.yaml`)
- **Replicas:** 3 instances for high availability
- **Resources:** CPU/Memory limits and requests
- **Health Checks:** Liveness and readiness probes
- **Environment:** Production configuration

### Service (`k8s/service.yaml`)
- **Type:** LoadBalancer for external access
- **Port Mapping:** 80 → 3000
- **Selector:** Routes traffic to app pods

### Ingress (`k8s/ingress.yaml`)
- **ALB Integration:** AWS Application Load Balancer
- **Health Check:** Uses `/live` endpoint
- **Scheme:** Internet-facing for public access

## Accessing the Application

After successful deployment, the application will be available via:

### 1. LoadBalancer Service
```bash
kubectl get service solar-system-service
# Access via the EXTERNAL-IP shown
```

### 2. ALB Ingress
```bash
kubectl get ingress solar-system-ingress
# Access via the ADDRESS shown
```

### 3. Port Forward (for testing)
```bash
kubectl port-forward service/solar-system-service 8080:80
# Access via http://localhost:8080
```

## Monitoring and Troubleshooting

### Check Deployment Status
```bash
kubectl get pods -l app=solar-system
kubectl logs -l app=solar-system
kubectl describe deployment solar-system-deployment
```

### Check Service Status
```bash
kubectl get services
kubectl describe service solar-system-service
```

### Check Ingress Status
```bash
kubectl get ingress
kubectl describe ingress solar-system-ingress
```

### Pipeline Debugging
1. Check Azure Pipeline logs for detailed error messages
2. Verify AWS credentials and permissions
3. Ensure EKS cluster is accessible
4. Validate Kubernetes manifests syntax

## Security Best Practices

1. **Secrets Management**: Use Azure Key Vault for sensitive data
2. **RBAC**: Implement Kubernetes Role-Based Access Control
3. **Network Policies**: Restrict pod-to-pod communication
4. **Image Security**: Scan Docker images for vulnerabilities

## Cleanup

To remove the deployment:
```bash
kubectl delete -f k8s/
```

To delete the EKS cluster:
```bash
eksctl delete cluster --name solar-system-cluster --region us-west-2
```

## Next Steps

1. Set up monitoring with Prometheus and Grafana
2. Implement automated testing in the pipeline
3. Add multiple environments (dev, staging, prod)
4. Configure auto-scaling based on metrics
5. Set up log aggregation with ELK stack
