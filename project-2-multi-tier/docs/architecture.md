# Project 2: Multi-Tier Web Application

## Overview

A three-tier web application deployed on AWS with proper network isolation,
security group segmentation, and Infrastructure as Code. This project
demonstrates VPC design, subnetting, EC2 management, RDS database
deployment, and least-privilege security principles.

## Architecture

![Architecture Diagram](https://raw.githubusercontent.com/ZeiadAlOmari/cloud-portfolio/main/project-2-multi-tier/diagrams/project2-architecture.drawio.png)

### Components

| Tier | Component | Subnet | Purpose |
|---|---|---|---|
| **Web** | Nginx on EC2 | Public | Reverse proxy, accepts HTTP traffic from internet |
| **App** | Flask on EC2 | Private | Application logic, API endpoints |
| **Database** | PostgreSQL on RDS | Isolated | Data storage, no internet access |
| **NAT** | NAT Instance on EC2 | Public | Allows private/isolated subnets to reach internet for updates |

### Network Design

    Internet
        |
    [Internet Gateway]
        |
    ┌─────────────────────────────────────────────────┐
    │                  VPC (10.0.0.0/16)               │
    │                                                   │
    │  ┌─────────────────────────────────┐              │
    │  │  Public Subnet (10.0.1.0/24)    │              │
    │  │  - Nginx Web Server             │              │
    │  │  - NAT Instance                 │              │
    │  └─────────────────────────────────┘              │
    │           |                                       │
    │  ┌─────────────────────────────────┐              │
    │  │  Private Subnet (10.0.10.0/24)  │              │
    │  │  - Flask App Server             │              │
    │  └─────────────────────────────────┘              │
    │           |                                       │
    │  ┌─────────────────────────────────┐              │
    │  │  Isolated Subnet (10.0.20.0/24) │              │
    │  │  - PostgreSQL RDS               │              │
    │  └─────────────────────────────────┘              │
    │                                                   │
    └─────────────────────────────────────────────────┘

### Security Group Rules

| Security Group | Inbound | Source | Purpose |
|---|---|---|---|
| **Web (Nginx)** | TCP 80 | 0.0.0.0/0 | HTTP from internet |
| **Web (Nginx)** | TCP 22 | 0.0.0.0/0 | SSH access |
| **App (Flask)** | TCP 5000 | Web SG only | Traffic from Nginx only |
| **App (Flask)** | TCP 22 | VPC CIDR | SSH from within VPC |
| **Database (RDS)** | TCP 5432 | App SG only | Traffic from Flask only |
| **NAT Instance** | All | Private subnets | Forward traffic for private subnets |

### Traffic Flow

1. User sends HTTP request to the web server's public IP
2. Nginx receives the request on port 80
3. Nginx proxies the request to Flask on port 5000 (private subnet)
4. Flask processes the request
5. If database access is needed, Flask connects to RDS on port 5432 (isolated subnet)
6. Response flows back through the same path

## Design Decisions

**Why three separate subnets?**
Network isolation is a fundamental security principle. Each tier only
communicates with the tier directly above or below it. If the web server
is compromised, the attacker cannot directly reach the database.

**Why Nginx instead of ALB?**
An ALB costs ~$16/month. Nginx on a free-tier EC2 instance teaches the
same reverse proxy concepts at zero cost. In production, an ALB would
be preferred for managed health checks, auto-scaling integration, and
built-in redundancy.

**Why a NAT Instance instead of NAT Gateway?**
A NAT Gateway costs ~$32/month. A NAT Instance (t3.micro EC2) performs
the same function within the free tier. The tradeoff is that you manage
it yourself — no built-in redundancy or automatic failover.

**Why Single-AZ RDS?**
Multi-AZ RDS doubles the cost. For learning purposes, Single-AZ teaches
the same database deployment concepts. In production, Multi-AZ is
essential for high availability.

**Why PostgreSQL?**
PostgreSQL is the most popular open-source relational database in cloud
environments. It's the default choice for most modern applications and
is well-supported on AWS RDS.

## Cost Analysis

| Resource | Free Tier | Production Equivalent | Production Cost |
|---|---|---|---|
| EC2 t3.micro x3 | $0 (750 hrs shared) | t3.small x3 | ~$45/month |
| RDS db.t3.micro | $0 (750 hrs) | db.t3.small Multi-AZ | ~$40/month |
| NAT Instance | $0 (included in EC2) | NAT Gateway | ~$32/month |
| ALB (not used) | $0 | ALB | ~$16/month |
| **Total** | **$0** | | **~$133/month** |

## What I Would Change for Production

1. **Replace Nginx with ALB** for managed load balancing and health checks
2. **Replace NAT Instance with NAT Gateway** for redundant internet access
3. **Enable Multi-AZ RDS** for automatic database failover
4. **Add Auto Scaling Group** for the app tier behind the ALB
5. **Use IAM roles** instead of hardcoded credentials on EC2 instances
6. **Add AWS Secrets Manager** for database credentials
7. **Enable RDS encryption at rest** and enforce TLS connections
8. **Add VPC Flow Logs** for network traffic auditing
9. **Use private subnets for the web tier** with ALB as the only public entry point
10. **Add a WAF** in front of the ALB for application-layer protection

## Files

    project-2-multi-tier/
    ├── terraform/
    │   ├── providers.tf          # AWS provider configuration
    │   ├── networking.tf         # VPC, subnets, routing, NAT instance
    │   ├── security_groups.tf    # Firewall rules for each tier
    │   ├── compute.tf            # EC2 instances (web + app servers)
    │   ├── database.tf           # RDS PostgreSQL instance
    │   └── outputs.tf            # IPs, endpoints, credentials
    ├── app/
    │   ├── app.py                # Flask application
    │   ├── requirements.txt      # Python dependencies
    │   └── nginx.conf            # Nginx reverse proxy config
    ├── diagrams/
    │   └── project2-architecture.drawio.png
    └── docs/
        └── architecture.md       # This file

## How to Deploy

    # 1. Clone the repository
    git clone https://github.com/ZeiadAlOmari/cloud-portfolio.git
    cd cloud-portfolio/project-2-multi-tier/terraform

    # 2. Generate an SSH key (if you don't have one)
    ssh-keygen -t rsa -b 4096

    # 3. Initialize Terraform
    terraform init

    # 4. Preview what will be created
    terraform plan

    # 5. Deploy
    terraform apply

    # 6. Get the web server IP
    terraform output web_public_ip

    # 7. Test the application
    curl http://$(terraform output -raw web_public_ip)
    curl http://$(terraform output -raw web_public_ip)/health

    # 8. Stop instances when not in use (to stay within free tier)
    aws ec2 stop-instances --instance-ids \
      $(terraform output -raw web_instance_id) \
      $(terraform output -raw app_instance_id) \
      $(terraform output -raw nat_instance_id)

    # 9. Start instances when needed
    aws ec2 start-instances --instance-ids <instance-ids>

    # 10. Destroy everything when done
    terraform destroy

## Lessons Learned

- Amazon Linux 2 requires amazon-linux-extras for Nginx and Python 3
- NAT instances need explicit IP forwarding configuration (sysctl + iptables)
- User data scripts run only once at instance launch — if they fail, you must replace the instance
- Security groups are stateful — return traffic is automatically allowed
- PostgreSQL reserves certain usernames (like "admin") — use alternatives
- The free tier has shared hour limits across instance types — plan accordingly
- Always check the console output when user data scripts fail