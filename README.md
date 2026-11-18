# Cloud Portfolio

Hands-on cloud architecture and engineering projects on AWS, built with Terraform and GitHub Actions. Every project
has a README (architecture, design decisions, verification, cost and lessons), an editable diagram, and evidence.
All of them were built at **USD 0**: paid services were skipped and recorded as cost decisions. Each project was torn
down after testing, and the teardown checked with the AWS CLI. Project 1 is the one kept live.

| # | Project | What it shows | Status |
|---|---|---|---|
| 01 | [Static website](project-01-static-site/) | S3 + CloudFront with Origin Access Control, security headers, Terraform | 🟢 Live |
| 02 | [Multi-tier application](project-02-multi-tier/) | VPC with public, app and database tiers; Nginx, Flask, RDS | Torn down |
| 03 | [CI/CD pipeline](project-03-cicd-pipeline/) | GitHub Actions build, test and deploy to EC2 | Torn down |
| 04 | [Serverless pipeline](project-04-serverless-pipeline/) | API Gateway, Lambda, SQS, DynamoDB (rebuilt in Project 10) | Torn down |
| 05 | [Kubernetes](project-05-kubernetes/) | Two Flask microservices on k3s: deployments, services, service discovery | Torn down |
| 06 | [Security baseline](project-06-security/) | MFA-gated least-privilege role, CloudTrail, Access Analyzer, password policy | Torn down |
| 07 | [Multi-region DR](project-07-multi-region-dr/) | S3 cross-region replication and CloudFront origin failover, tested | Torn down |
| 08 | [Well-Architected review](project-08-well-architected/) | Six-pillar review of Projects 1–7: 69 findings, recorded in the AWS Well-Architected Tool | Review |
| 09 | [Keyless CI/CD](project-09-keyless-cicd/) | GitHub OIDC (no stored AWS keys), Checkov policy gate, plan/apply role split | 🟢 Running for Project 1 |
| 10 | [Serverless pipeline v2](project-10-serverless-v2/) | Project 4 rebuilt to fix the review's findings; IAM auth, idempotency, DLQ alarm, deploy switch | Torn down |
| 11 | [Secure supply chain](project-11-secure-supply-chain/) | Project 3's pipeline rebuilt: build once, Trivy gate, SBOM, keyless cosign signature, deploy by digest through SSM with no SSH | Torn down (signed images public) |

**How the later projects connect:** Project 8 reviewed Projects 1–7 against the AWS Well-Architected Framework.
Projects 9, 10 and 11 fix what it found, and its [findings register](project-08-well-architected/findings/findings-register.md)
tracks which findings are fixed and by which project.
