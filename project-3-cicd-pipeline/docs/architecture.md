# Project 3: CI/CD Pipeline for a Containerized Application

## Overview

A fully automated CI/CD pipeline that builds, tests, and deploys a
containerized Flask application to AWS EC2 using GitHub Actions.
This project demonstrates Docker containerization, automated testing,
pipeline design, and deployment automation.

## Architecture

![Architecture Diagram](https://raw.githubusercontent.com/ZeiadAlOmari/cloud-portfolio/main/project-3-cicd-pipeline/diagrams/project3-architecture.drawio.png)

### Components

| Component | Purpose |
|---|---|
| **GitHub** | Source code repository, triggers pipeline on push |
| **GitHub Actions** | Runs tests, builds Docker image, deploys to EC2 |
| **Docker** | Packages the application into a portable container |
| **EC2 (t3.micro)** | Hosts the running container |
| **Terraform** | Provisions the EC2 instance and security group |

### Pipeline Stages

    Developer
        |
        | git push
        v
    GitHub Repository
        |
        | triggers workflow
        v
    GitHub Actions
        |
        ├── Stage 1: Test
        |   - Install Python dependencies
        |   - Run pytest against the application
        |
        ├── Stage 2: Build
        |   - Build Docker image
        |   - Run container and test /health endpoint
        |
        └── Stage 3: Deploy (main branch only)
            - SSH into EC2 instance
            - Pull latest code
            - Rebuild Docker image
            - Restart container

### How It Works

1. Developer pushes code to the main branch on GitHub
2. GitHub Actions triggers the workflow automatically
3. The test job installs dependencies and runs pytest
4. The build job creates a Docker image and verifies it runs
5. The deploy job SSHs into the EC2 instance and pulls the latest code
6. Docker rebuilds the image and restarts the container
7. The new version is live within minutes

## Design Decisions

**Why GitHub Actions instead of Jenkins/CodePipeline?**
GitHub Actions is free for public repos (unlimited minutes) and
2,000 minutes/month for private repos. It lives alongside the code,
requires no separate server, and is the most common CI/CD tool for
open-source projects. It is also vendor-neutral and works with any cloud.

**Why Docker?**
Containers ensure the application runs identically in development,
testing, and production. Docker also makes deployments atomic — the
old container stops and the new one starts with zero configuration drift.

**Why deploy to EC2 instead of ECS/EKS?**
For a single-container application, EC2 is simpler and cheaper.
ECS and Kubernetes add orchestration complexity that is not needed
for a single service. This project focuses on the CI/CD pipeline
itself, not container orchestration.

**Why SSH-based deployment?**
For a single-server deployment, SSH is the simplest approach.
For production, you would use a deployment tool like AWS CodeDeploy,
ArgoCD, or a container registry (ECR) with ECS pulling new images.

**Why three separate pipeline stages?**
Separating test, build, and deploy ensures:
- Tests must pass before building (fail fast)
- Build must succeed before deploying (no broken deployments)
- Deploy only runs on main branch pushes (not pull requests)

## Cost Analysis

| Resource | Free Tier | Production Equivalent | Production Cost |
|---|---|---|---|
| EC2 t3.micro | $0 (750 hrs) | t3.small | ~$15/month |
| GitHub Actions | $0 (public repo) | Private: 2,000 min/mo | $0-4/month |
| Docker Hub | $0 (public images) | ECR | ~$1/month |
| **Total** | **$0** | | **~$16-20/month** |

## What I Would Change for Production

1. **Push Docker images to ECR** instead of building on the server
2. **Use ECS or EKS** to run containers instead of raw EC2
3. **Add staging environment** — deploy to staging first, then promote to production
4. **Add rollback capability** — keep previous Docker image tagged and ready
5. **Use GitHub Environments** with approval gates for production deploys
6. **Add monitoring** — CloudWatch alarms for container health
7. **Use AWS Secrets Manager** for any sensitive configuration
8. **Add vulnerability scanning** — scan Docker images before deployment
9. **Use OIDC for AWS authentication** instead of storing access keys in GitHub secrets

## Files

    project-3-cicd-pipeline/
    ├── .github/
    │   └── workflows/
    │       └── ci-cd.yml          # GitHub Actions pipeline
    ├── terraform/
    │   ├── providers.tf           # AWS provider configuration
    │   ├── main.tf                # EC2 instance and security group
    │   └── outputs.tf             # Instance IP and URL
    ├── app/
    │   ├── app.py                 # Flask application
    │   ├── Dockerfile             # Container definition
    │   ├── requirements.txt       # Python dependencies
    │   └── test_app.py            # Automated tests
    ├── diagrams/
    │   └── project3-architecture.drawio.png
    └── docs/
        └── architecture.md        # This file

## How to Deploy

    # 1. Clone the repository
    git clone https://github.com/ZeiadAlOmari/cloud-portfolio.git
    cd cloud-portfolio/project-3-cicd-pipeline/terraform

    # 2. Initialize and deploy the EC2 instance
    terraform init
    terraform apply

    # 3. Wait 3 minutes for user_data to complete

    # 4. Test the application
    curl http://$(terraform output -raw instance_public_ip)

    # 5. Push a code change to trigger the CI/CD pipeline
    # Edit app.py, commit, and push to main

    # 6. Watch the pipeline run
    # Go to GitHub > Actions tab to see the workflow

    # 7. Destroy when done
    terraform destroy

## Lessons Learned

- User data scripts run as root — Docker commands work without sudo
- Amazon Linux 2023 uses dnf, not yum
- The Dockerfile must be in the repo before the pipeline can build
- GitHub Actions needs AWS credentials stored as repository secrets
- SSH-based deployment is simple but does not scale — use a proper
  deployment tool for production
- Docker containers should be treated as immutable — never modify
  a running container, always rebuild and replace
