# Solar System NodeJS Application

A simple HTML+MongoDB+NodeJS project to display Solar System and it's planets with complete DevOps pipeline including Docker containerization, CI/CD, and AWS EKS deployment using Terraform.

## 🚀 Quick Start Options

### Option 1: Run Locally
```bash
npm install
npm start
# Access at http://localhost:3000
```

### Option 2: Run with Docker
```bash
docker run -p 3000:3000 --name solar-system moheie/solar-system:latest
# Access at http://localhost:3000
```

### Option 3: Deploy to AWS EKS with Terraform (Recommended)
```powershell
# Windows PowerShell
.\scripts\deploy-terraform.ps1

# Linux/macOS/Git Bash
./scripts/deploy-terraform.sh
```

---
## 📋 Requirements

For development, you will only need Node.js and NPM installed in your environment.

### Node
- #### Node installation on Windows

  Just go on [official Node.js website](https://nodejs.org/) and download the installer.
Also, be sure to have `git` available in your PATH, `npm` might need it (You can find git [here](https://git-scm.com/)).

- #### Node installation on Ubuntu

  You can install nodejs and npm easily with apt install, just run the following commands.

      $ sudo apt install nodejs
      $ sudo apt install npm

- #### Other Operating Systems
  You can find more information about the installation on the [official Node.js website](https://nodejs.org/) and the [official NPM website](https://npmjs.org/).

If the installation was successful, you should be able to run the following command.

    $ node --version
    v8.11.3

    $ npm --version
    6.1.0

---
## Install Dependencies from `package.json`
    $ npm install

## Run Unit Testing
    $ npm test

## Run Code Coverage
    $ npm run coverage


## Run Application
    $ npm start

## Run with Docker
    docker run -p 3000:3000 --name solar-system <your-dockerhub-username>/solar-system:latest

## Access Application on Browser
    http://localhost:3000/

---
## 🏗️ DevOps & Infrastructure

This project includes complete DevOps automation with multiple deployment options:

### Infrastructure as Code with Terraform
- **Location**: `./terraform/`
- **Features**: Complete AWS EKS cluster with VPC, security groups, and load balancers
- **Deployment**: Automated with PowerShell/Bash scripts
- **Cleanup**: Automated resource cleanup to prevent costs

### CI/CD Pipelines
- **GitHub Actions**: `/.github/workflows/` - Docker build and push to Docker Hub
- **Azure Pipelines**: 
  - `azure-pipelines-cd.yml` - Manual EKS deployment
  - `azure-pipelines-terraform.yml` - Terraform-based deployment

### Docker Containerization
- **Multi-stage build** with Node.js 18 Alpine
- **Production-ready** with health checks and security
- **Published** to Docker Hub: `moheie/solar-system:latest`

### Kubernetes Manifests
- **Location**: `./kubernetes/`
- **Environments**: Development and Staging configurations
- **Features**: Deployments, services, ingress, and health checks

### Deployment Scripts
- **`./scripts/deploy-terraform.ps1`** - PowerShell deployment script
- **`./scripts/deploy-terraform.sh`** - Bash deployment script  
- **`./scripts/cleanup-terraform.ps1`** - PowerShell cleanup script
- **`./scripts/cleanup-terraform.sh`** - Bash cleanup script

## 📊 Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   GitHub Repo   │────│  Azure Pipeline │────│   AWS EKS       │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Source Code │ │    │ │ Terraform   │ │    │ │ Solar System│ │
│ │ Dockerfile  │ │    │ │ Deploy      │ │    │ │ Application │ │
│ │ K8s Manifests│ │    │ │ Test        │ │    │ │ (3 Pods)    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Docker Hub    │    │   Terraform     │    │   LoadBalancer  │
│                 │    │   State         │    │                 │
│ moheie/solar-   │    │                 │    │ Public Access   │
│ system:latest   │    │ Infrastructure  │    │ HTTP Endpoint   │
│                 │    │ as Code         │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 💰 Cost Management

**Estimated AWS Costs**: ~$250/month for complete EKS setup

**Always cleanup resources when done**:
```powershell
# PowerShell
.\scripts\cleanup-terraform.ps1

# Bash  
./scripts/cleanup-terraform.sh
```

## 📚 Documentation

- **[Terraform Setup Guide](./terraform/README.md)** - Complete infrastructure deployment guide
- **[CI/CD Pipeline Setup](./docs/pipeline-setup.md)** - Azure DevOps configuration
- **[Kubernetes Deployment](./kubernetes/README.md)** - Manual K8s deployment guide

## 🛠️ Development

