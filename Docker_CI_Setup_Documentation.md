# Docker CI/CD Setup Documentation
## Solar System NodeJS Application

**Date:** August 21, 2025  
**Project:** Solar System NodeJS Application  
**Repository:** moheie/BMDEV  

---

## Table of Contents
1. [Project Overview](#project-overview)
2. [Dockerfile Implementation](#dockerfile-implementation)
3. [CI/CD Workflow Setup](#cicd-workflow-setup)
4. [Docker Hub Integration](#docker-hub-integration)
5. [Running the Application](#running-the-application)
6. [GitHub Secrets Configuration](#github-secrets-configuration)

---

## 1. Project Overview

The Solar System NodeJS Application is a web application that displays information about planets in our solar system. This document provides a complete guide for:

- Creating a production-ready Dockerfile
- Setting up automated CI/CD pipeline with GitHub Actions
- Publishing Docker images to Docker Hub
- Running the containerized application

**Technology Stack:**
- Node.js 18
- Express.js
- MongoDB
- Docker
- GitHub Actions

---

## 2. Dockerfile Implementation

### Location: `/Dockerfile` (Repository Root)

```dockerfile
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm install --production

COPY . .

ENV MONGO_URI=mongodb+srv://supercluster.d83jj.mongodb.net/superData
ENV MONGO_USERNAME=superuser
ENV MONGO_PASSWORD=SuperPassword

EXPOSE 3000

CMD ["npm", "start"]
```

### Dockerfile Features:
- **Base Image:** `node:18-alpine` for minimal size and security
- **Production Dependencies:** Only installs production dependencies
- **Environment Variables:** Pre-configured MongoDB connection
- **Port Exposure:** Port 3000 for web application
- **Optimized Layering:** Package files copied separately for better caching

### Build Verification:
```bash
docker build -t solar-system:latest .
```

**Build Status:** ✅ Successfully built (Image ID: 99f9549ab1e9, Size: 202MB)

---

## 3. CI/CD Workflow Setup

### Location: `/.github/workflows/docker-build.yml`

```yaml
name: Build and Push Docker Image

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Extract version
        id: vars
        run: |
          echo "version=$(jq -r .version package.json)" >> $GITHUB_OUTPUT

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ secrets.DOCKERHUB_USERNAME }}/solar-system:latest,${{ secrets.DOCKERHUB_USERNAME }}/solar-system:${{ steps.vars.outputs.version }}
```

### Workflow Features:
- **Trigger:** Automatic build on push to main branch
- **Multi-tag Support:** Creates both `latest` and version-specific tags
- **Version Extraction:** Automatically reads version from package.json (currently v6.7.6)
- **Docker Buildx:** Enhanced build capabilities
- **Security:** Uses GitHub secrets for Docker Hub authentication

---

## 4. Docker Hub Integration

### Image Repository Structure:
```
Docker Hub Repository: [username]/solar-system

Available Tags:
├── latest (always points to most recent build)
└── 6.7.6 (current application version)
```

### Image Naming Convention:
- **Latest:** `[username]/solar-system:latest`
- **Versioned:** `[username]/solar-system:6.7.6`

### Automated Publishing:
- Images are automatically built and pushed on every commit to main branch
- Both `latest` and semantic version tags are created
- Images are publicly available on Docker Hub

---

## 5. Running the Application

### Local Development:
```bash
# Clone repository
git clone https://github.com/moheie/BMDEV.git
cd BMDEV

# Install dependencies
npm install

# Run application
npm start
```

### Docker Commands:

#### Pull and Run from Docker Hub:
```bash
# Pull the latest image
docker pull [username]/solar-system:latest

# Run the container
docker run -p 3000:3000 --name solar-system [username]/solar-system:latest
```

#### Build and Run Locally:
```bash
# Build image locally
docker build -t solar-system:latest .

# Run the container
docker run -p 3000:3000 --name solar-system solar-system:latest
```

#### Container Management:
```bash
# Stop the container
docker stop solar-system

# Remove the container
docker rm solar-system

# View running containers
docker ps

# View container logs
docker logs solar-system
```

### Access Application:
- **URL:** http://localhost:3000
- **Health Check:** http://localhost:3000/live
- **Ready Check:** http://localhost:3000/ready
- **OS Info:** http://localhost:3000/os

---

## 6. GitHub Secrets Configuration

### Required Secrets:

#### DOCKERHUB_USERNAME
- **Purpose:** Docker Hub username for authentication
- **Value:** Your Docker Hub username
- **Location:** Repository Settings → Secrets and variables → Actions

#### DOCKERHUB_TOKEN
- **Purpose:** Docker Hub access token for secure authentication
- **Value:** Generated access token from Docker Hub
- **Security:** Preferred over password for CI/CD workflows

### Setup Steps:

1. **Navigate to Repository Settings:**
   - Go to: https://github.com/moheie/BMDEV
   - Click: Settings → Secrets and variables → Actions

2. **Create Docker Hub Access Token:**
   - Login to Docker Hub
   - Go to: Account Settings → Security
   - Click: New Access Token
   - Name: "GitHub Actions"
   - Permissions: Read, Write, Delete
   - Copy token immediately

3. **Add GitHub Secrets:**
   - Click "New repository secret"
   - Add `DOCKERHUB_USERNAME` with your username
   - Add `DOCKERHUB_TOKEN` with the access token

### Verification:
After setup, push any change to main branch to trigger the workflow and verify:
- Workflow runs successfully
- Image is built and pushed to Docker Hub
- Both tags are created (latest and version)

---

## Summary

This setup provides:
- ✅ **Minimal, production-ready Dockerfile** at repository root
- ✅ **Automated CI workflow** that builds and pushes on every commit to main
- ✅ **Docker Hub integration** with both latest and versioned tags
- ✅ **Complete documentation** for running the application with Docker
- ✅ **Security best practices** using GitHub secrets

The application is now ready for production deployment with full CI/CD automation.
