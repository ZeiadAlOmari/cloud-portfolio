# Project 3: CI/CD Pipeline for a Containerized Application

A fully automated CI/CD pipeline that builds, tests, and deploys a containerized Flask application to AWS EC2 using GitHub Actions.

## Architecture

![Architecture Diagram](https://raw.githubusercontent.com/ZeiadAlOmari/cloud-portfolio/main/project-3-cicd-pipeline/diagrams/project3-architecture.drawio.png)

## Overview

| Component | Technology | Purpose |
|---|---|---|
| Source Control | GitHub | Code repository, triggers pipeline |
| CI/CD | GitHub Actions | Automated test, build, deploy |
| Containerization | Docker | Portable application packaging |
| Compute | EC2 t3.micro | Hosts the running container |
| IaC | Terraform | Provisions AWS infrastructure |

## Pipeline Flow

    git push → GitHub → GitHub Actions → Test → Build → Deploy → EC2

## Key Skills Demonstrated

- Docker containerization and Dockerfile authoring
- GitHub Actions workflow design with multiple stages
- Automated testing in CI pipelines
- Container deployment to EC2
- Infrastructure as Code with Terraform
- CI/CD best practices (fail fast, deploy only on main)

## Quick Start

    cd terraform
    terraform init
    terraform apply

## Documentation

See [docs/architecture.md](docs/architecture.md) for full architecture details, design decisions, and cost analysis.
