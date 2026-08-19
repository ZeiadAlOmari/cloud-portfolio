# Project 1: Static Website Hosting with IaC

## Overview

A static portfolio website hosted entirely on AWS, provisioned and managed
through Terraform Infrastructure as Code. This project demonstrates core
cloud infrastructure skills: object storage, CDN configuration, TLS/HTTPS,
DNS-ready architecture, and reproducible deployments.

## Architecture

![Architecture Diagram](../diagrams/project1-architecture.drawio.png)

### Components

| Component | Purpose | Free Tier |
|---|---|---|
| **S3 Bucket** | Stores and serves static HTML | 5 GB storage |
| **CloudFront CDN** | Caches content globally, enforces HTTPS | 1 TB transfer |
| **ACM Certificate** | Provides TLS certificate for HTTPS | Free (with custom domain) |
| **Terraform** | Provisions all infrastructure as code | Free (open source) |

### How It Works

1. User visits the CloudFront URL over HTTPS
2. CloudFront checks its edge cache for the content
3. If not cached, CloudFront requests the file from the S3 origin over HTTP
4. S3 returns the static HTML file
5. CloudFront caches the file at the edge and serves it to the user
6. Subsequent requests from nearby users are served from cache

### Traffic Flow

    User (HTTPS) → CloudFront CDN → S3 Bucket (HTTP origin)
                      ↓
                ACM (TLS Certificate)

## Design Decisions

**Why S3 for static hosting?**
S3 is purpose-built for object storage. It's cheaper and more reliable
than running a web server on EC2. No server to patch, no OS to maintain,
and it scales automatically.

**Why CloudFront in front of S3?**
Three reasons:
- HTTPS support (S3 website endpoints only support HTTP)
- Global CDN caching for faster load times worldwide
- DDoS protection through AWS Shield (included free)

**Why PriceClass_100?**
CloudFront offers three pricing tiers. PriceClass_100 covers North America
and Europe only, which is the cheapest option. For a portfolio site, full
global coverage (PriceClass_All) isn't necessary.

**Why not a custom domain?**
A custom domain requires Route 53 ($0.50/month for hosted zone + domain
purchase). This project uses the free CloudFront distribution URL to stay
within the free tier. A custom domain can be added later.

## Cost Analysis

| Resource | Monthly Cost (Free Tier) | Monthly Cost (After Free Tier) |
|---|---|---|
| S3 (storage + requests) | $0.00 | ~$0.05 |
| CloudFront (transfer + requests) | $0.00 | ~$0.50 |
| **Total** | **$0.00** | **~$0.55** |

## What I Would Change for Production

1. **Add a custom domain** with Route 53 and a dedicated ACM certificate
2. **Add a proper ACM certificate** attached to the CloudFront distribution
3. **Enable S3 versioning** to keep a history of file changes
4. **Add CloudFront logging** to an S3 bucket for access analytics
5. **Use S3 + CloudFront Origin Access Control** instead of public bucket
   policy for better security
6. **Add a CI/CD pipeline** that automatically deploys on git push
7. **Add a CloudFront function** to handle URL redirects (e.g., /about → /about.html)

## Files

    project-1-static-site/
    ├── terraform/
    │   ├── providers.tf      # AWS provider configuration
    │   ├── s3.tf             # S3 bucket, policy, and website hosting
    │   ├── cloudfront.tf     # CloudFront CDN distribution
    │   └── outputs.tf        # Useful outputs (URLs, bucket name)
    ├── site/
    │   └── index.html        # Static portfolio website
    ├── diagrams/
    │   └── project1-architecture.drawio.png
    └── docs/
        └── architecture.md   # This file

## How to Deploy

    # 1. Clone the repository
    git clone https://github.com/ZeiadAlOmari/cloud-portfolio.git
    cd cloud-portfolio/project-1-static-site/terraform

    # 2. Initialize Terraform
    terraform init

    # 3. Preview what will be created
    terraform plan

    # 4. Deploy
    terraform apply

    # 5. Get the website URL
    terraform output

    # 6. When done, destroy all resources
    terraform destroy

## Lessons Learned

- S3 bucket names must be globally unique across all AWS accounts
- CloudFront distributions take several minutes to deploy
- ACM certificates for CloudFront must be created in us-east-1
- Terraform's `plan` command is essential for previewing changes safely
- Free tier limits are generous enough for learning and portfolio projects