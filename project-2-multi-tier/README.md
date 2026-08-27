# Project 2: Multi-Tier Web Application

A three-tier web application deployed on AWS with proper network isolation, security group segmentation, and Infrastructure as Code.

## Architecture

![Architecture Diagram](https://raw.githubusercontent.com/ZeiadAlOmari/cloud-portfolio/main/project-2-multi-tier/diagrams/project2-architecture.drawio.png)

## Overview

| Tier | Component | Subnet | Purpose |
|---|---|---|---|
| Web | Nginx on EC2 | Public | Reverse proxy, accepts HTTP traffic |
| App | Flask on EC2 | Private | Application logic, API endpoints |
| Database | PostgreSQL on RDS | Isolated | Data storage, no internet access |
| NAT | NAT Instance on EC2 | Public | Outbound internet for private subnets |

## Key Skills Demonstrated

- VPC design with public, private, and isolated subnets
- Security group configuration with least-privilege rules
- NAT instance setup as a cost-effective alternative to NAT Gateway
- RDS PostgreSQL deployment in isolated subnets
- Nginx reverse proxy configuration
- Flask application deployment
- Infrastructure as Code with Terraform
- Cost-optimized architecture using AWS Free Tier

## Quick Start

    cd terraform
    terraform init
    terraform plan
    terraform apply

## Documentation

See [docs/architecture.md](docs/architecture.md) for full architecture details, design decisions, and cost analysis.
