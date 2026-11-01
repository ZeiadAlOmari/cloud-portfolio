# Findings Register — Project 8 Well-Architected Review

One row per finding across the AWS account and Projects 1–7. IDs are stable and are cited in the
Well-Architected Tool answer notes. Evidence numbers refer to files in [`../evidence/`](../evidence/).

**Status key**

| Status | Meaning |
|---|---|
| Remediated | Fixed during this review and independently verified |
| Cost decision | Known gap accepted because the fix is not free (zero-spend rule) |
| Design finding | Gap in an as-built project that is now torn down; recorded with the free fix |
| Lesson | Process or habit finding; no resource to change |
| Open | Still to do |
| Closed | Investigated and not a gap, or merged into another finding |
| Strength | Good practice worth keeping |

## Summary

| Status | High | Medium | Low | — | Total |
|---|---|---|---|---|---|
| Remediated | 3 | 4 | 6 | · | **13** |
| Cost decision | 3 | 3 | 4 | · | **10** |
| Design finding | 6 | 14 | 5 | · | **25** |
| Lesson | · | 2 | · | · | **2** |
| Open | · | · | 1 | · | **1** |
| Closed | · | 1 | 1 | 4 | **6** |
| Strength | · | · | · | 12 | **12** |
| **Total** | 12 | 24 | 17 | 16 | **69** |

## All findings

| ID | Scope | Pillar | WA question | Risk | Status | Finding | Evidence |
|---|---|---|---|---|---|---|---|
| F-02 | Account | SEC | `identities` | 🔴 High | Remediated | Admin IAM user (AdministratorAccess) used via a 68-day-old long-lived access key | 00, 01, 30, 31, 32 |
| F-04 | P1 | SEC | `protect-data-rest` | 🔴 High | Remediated | Site bucket publicly readable - Block Public Access off, `Principal: *` policy, no OAC | 15, 16, 18, 19 |
| F-36 | P4 | OPS, COST | `decomissioning-resources` | 🔴 High | Remediated | Project 4 never destroyed - 21 resources live ~8 weeks | 04, 05, 06, 07, 08, 09 |
| F-03 | Account | SEC | `identities` | 🟠 Medium | Remediated | No IAM password policy (P6 teardown regression) | 02, 20 |
| F-05 | P1 | SEC | `protect-data-transit` | 🟠 Medium | Remediated | CloudFront-to-S3 hop over HTTP (website endpoint is http-only) | 15, 19 |
| F-35 | Account | SEC | `permissions` | 🟠 Medium | Remediated | No IAM Access Analyzer (P6 teardown regression) | 02, 21 |
| F-40 | P4 | OPS, COST | `decomissioning-resources` | 🟠 Medium | Remediated | Lambda log groups not Terraform-managed (never-expire retention) and orphaned by destroy | 09, 10 |
| F-37 | P4 | OPS, COST | `decomissioning-resources` | 🟡 Low | Remediated | Retired SAM version left its `aws-sam-cli-managed-default` bootstrap stack | 06, 11, 12, 13 |
| F-52 | P4 | COST, SUS | `decomissioning-resources` | 🟡 Low | Remediated | Versioned SAM bucket kept 8 noncurrent versions behind delete markers | 11 |
| F-54 | P1 | COST | `data-transfer` | 🟡 Low | Remediated | Direct bucket reads bypassed CloudFront caching and free tier | 18, 19 |
| F-58 | P1 | PERF | `networking` | 🟡 Low | Remediated | HTTP/2 only | 19 |
| F-60 | Repo | SEC, OPS | `dev-integ` | 🟡 Low | Remediated | `*tfplan*` not ignored; stray empty `terraform.tfstate` at repo root | 06, 17, 34 |
| F-63 | Account | COST | `cloud-financial-management` | 🟡 Low | Remediated | Budget threshold too loose for a zero-spend account | 22, 28 |
| F-01 | Account | SEC | `detect-investigate-events` | 🔴 High | Cost decision | No CloudTrail trail - Project 6 teardown removed it | 02, 22, 27 |
| F-06 | P5 | REL | `fault-isolation` | 🔴 High | Cost decision | Single k3s node in one AZ; 1 GB swap is a workaround, not capacity | P5 docs |
| F-17 | P2 | REL | `fault-isolation` | 🔴 High | Cost decision | Single AZ: single web and app instances, no ALB/ASG, Single-AZ RDS | P2 docs |
| F-18 | P2 | REL | `withstand-component-failures` | 🟠 Medium | Cost decision | NAT instance is a single point of failure with no auto-recovery | P2 docs |
| F-19 | P2 | OPS, SEC | `monitor-aws-resources` | 🟠 Medium | Cost decision | No VPC Flow Logs, health monitoring or alarms | P2 docs |
| F-66 | Account | SEC, COST | `identities` | 🟠 Medium | Cost decision | IAM Identity Center not adopted | 30 |
| F-49 | P4 | REL | `backing-up-data` | 🟡 Low | Cost decision | DynamoDB PITR off (paid); deletion protection off (free) | 08 |
| F-55 | P1 | SEC | `protect-data-transit` | 🟡 Low | Cost decision | Minimum viewer TLS is TLSv1 on the default *.cloudfront.net certificate | 15 |
| F-56 | P1 | OPS | `workload-observability` | 🟡 Low | Cost decision | CloudFront access logging off | 15 |
| F-57 | P1 | REL | `backing-up-data` | 🟡 Low | Cost decision | Bucket versioning not enabled | 15 |
| F-12 | P2 | SEC | `network-protection` | 🔴 High | Design finding | SSH (22) open to 0.0.0.0/0 on the web tier | P2 docs |
| F-13 | P2 | SEC | `identities` | 🔴 High | Design finding | DB credentials hardcoded on EC2 and exposed through `outputs.tf` / state | P2 docs |
| F-23 | P3 | SEC | `application-security` | 🔴 High | Design finding | Pipeline design uses static AWS keys and an SSH private key in GitHub Secrets; no OIDC | 03, P3 workflow |
| F-29 | P3 | SEC | `network-protection` | 🔴 High | Design finding | SSH deploy from GitHub-hosted runners implies port 22 open to the internet | P3 workflow |
| F-42 | P4 | SEC | `application-security` | 🔴 High | Design finding | All four HTTP API routes `authorization_type: NONE` - POST /ingest writable by anyone | 08 |
| F-43 | P4 | REL, SEC, COST | `mitigate-interaction-failure` | 🔴 High | Design finding | No stage throttling (0/0) - denial-of-wallet exposure combined with F-42 | 08 |
| F-07 | P5 | SEC | `network-protection` | 🟠 Medium | Design finding | NodePort 30080 exposed directly; no ingress or TLS | P5 docs |
| F-08 | P7 | REL | `planning-for-recovery` | 🟠 Medium | Design finding | RPO based on a single 26s replication sample; S3 RTC (paid) not used | P7 docs |
| F-09 | P7 | REL | `planning-for-recovery` | 🟠 Medium | Design finding | One-way replication - failback is manual and has no runbook | P7 docs |
| F-14 | P2 | SEC | `protect-data-rest` | 🟠 Medium | Design finding | RDS not encrypted at rest; TLS not enforced | P2 docs |
| F-15 | P2 | SEC | `protect-data-transit` | 🟠 Medium | Design finding | Web tier serves HTTP only | P2 docs |
| F-16 | P2 | OPS, SEC | `dev-integ` | 🟠 Medium | Design finding | Built on Amazon Linux 2, which reached end of support on 2026-06-30 | P2 docs |
| F-30 | P3 | OPS, REL | `dev-integ` | 🟠 Medium | Design finding | Tested artifact is not the deployed artifact | P3 workflow |
| F-31 | P3 | REL | `mit-deploy-risks` | 🟠 Medium | Design finding | Stop/remove/run causes downtime on every deploy; no rollback image | P3 workflow |
| F-32 | P3 | SEC | `protect-compute` | 🟠 Medium | Design finding | No image vulnerability scan; third-party action pinned by tag, not commit SHA | P3 workflow |
| F-38 | P4 | SEC | `permissions` | 🟠 Medium | Design finding | One IAM role shared by all three functions; `logs` on `arn:aws:logs:*:*:*` | 08 |
| F-39 | P4 | OPS, REL | `monitor-aws-resources` | 🟠 Medium | Design finding | No CloudWatch alarms, not even DLQ depth | 07, 08 |
| F-44 | P4 | REL | `prevent-interaction-failure` | 🟠 Medium | Design finding | SQS visibility timeout (60s) equals process timeout (60s) | 08 |
| F-45 | P4 | REL | `mitigate-interaction-failure` | 🟠 Medium | Design finding | No `ReportBatchItemFailures` - one bad message retries the whole batch of 10 | 08 |
| F-47 | P4 | OPS | `observability` | 🟠 Medium | Design finding | No API access logs, detailed metrics or X-Ray tracing (PassThrough) | 08 |
| F-33 | P3 | SEC | `application-security` | 🟡 Low | Design finding | No `permissions:` block, so GITHUB_TOKEN gets default scopes | P3 workflow |
| F-46 | P4 | REL | `mitigate-interaction-failure` | 🟡 Low | Design finding | DLQ retention (4 days) equals source queue retention | 08 |
| F-48 | P4 | PERF, COST | `data-management` | 🟡 Low | Design finding | /stats uses DynamoDB Scan - cost and latency grow with table size | 08 |
| F-50 | P4 | COST, SUS | `sus_hardware` | 🟡 Low | Design finding | x86_64 Lambdas | 08 |
| F-51 | P4 | REL | `mitigate-interaction-failure` | 🟡 Low | Design finding | No reserved concurrency | 08 |
| F-53 | Portfolio | OPS | `decomissioning-resources` | 🟠 Medium | Lesson | Resource Explorer index was stale and partial | 13, 14 |
| F-65 | Account | SEC | `securely-operate` | 🟠 Medium | Lesson | Root console session left signed in ~12 hours | 27 |
| F-20 | P2 | OPS | `dev-integ` | 🟡 Low | Open | P2 documentation predates portfolio conventions (no Components table, Known Limitations, teardown verification) | P2 docs |
| F-28 | Account | SEC | `securely-operate` | 🟠 Medium | Closed | Root console sign-in on 2026-10-20 | 01, 27 |
| F-61 | Account | COST | `cloud-financial-management` | 🟡 Low | Closed | October raw usage USD 0.017 | 22 |
| F-24 | P3 | REL | `mit-deploy-risks` | 🟢 — | Closed | Single EC2 deploy target | — |
| F-25 | P3 | SEC | `protect-compute` | 🟢 — | Closed | Image registry/scanning unknown | — |
| F-27 | P3 | SEC | `identities` | 🟢 — | Closed | Suspected admin key stored in GitHub | 03 |
| F-34 | P3 | OPS | `mit-deploy-risks` | 🟢 — | Closed | Suspected failing pipeline: workflow triggers on push but its secrets are gone | 34 |
| F-10 | Portfolio | OPS | `decomissioning-resources` | 🟢 — | Strength | Teardown-after-demo convention with independent CLI verification | 14 |
| F-11 | Portfolio | COST, SUS | `cloud-financial-management` | 🟢 — | Strength | Zero-spend outcome across seven projects | 22 |
| F-21 | P2 | COST | `select-service` | 🟢 — | Strength | NAT instance over NAT Gateway (~USD 32/month) and Nginx over ALB (~USD 16/month) | P2 docs |
| F-22 | P2 | OPS | `evolve-ops` | 🟢 — | Strength | 'What I Would Change for Production' section shows the trade-offs were understood | P2 docs |
| F-26 | P3 | OPS | `dev-integ` | 🟢 — | Strength | Test gate, container health test, deploy only on push to main, path filters | P3 workflow |
| F-41 | P4 | REL | `mitigate-interaction-failure` | 🟢 — | Strength | Dead-letter queue with redrive (maxReceiveCount 3) | 08 |
| F-59 | Repo | SEC | `securely-operate` | 🟢 — | Strength | No .tfstate or .tfvars file ever committed (current tree and full history) | 17 |
| F-62 | Account | COST | `cloud-financial-management` | 🟢 — | Strength | Monthly budget with ACTUAL 80%/100% and FORECASTED 100% email alerts | 22 |
| F-64 | Repo | SEC | `securely-operate` | 🟢 — | Strength | Account ID never present in tracked files or git history | — |
| F-67 | P1 | SEC, PERF, COST | `protect-data-transit` | 🟢 — | Strength | Viewer HTTPS redirect, SSE-S3, compression, PriceClass_100 | 15 |
| F-68 | P4 | SEC | `protect-data-rest` | 🟢 — | Strength | SQS SSE on both queues; IAM scoped to specific queue/table ARNs; DynamoDB encrypted | 08 |
| F-69 | Account | SEC | `securely-operate` | 🟢 — | Strength | Root has MFA and no access keys; admin has MFA | 01 |

## Detail

**F-01 — No CloudTrail trail - Project 6 teardown removed it**  
Account · Security · High · Cost decision  
Tearing down P6 deleted the account-level trail with the project stack. A trail is free but its S3 delivery is not; the free 90-day CloudTrail Event History is the compensating control and was verified recording every remediation call (and answered F-28).

**F-02 — Admin IAM user (AdministratorAccess) used via a 68-day-old long-lived access key**  
Account · Security · High · Remediated  
CLI moved to `aws login` (browser sign-in with MFA, temporary ASIA credentials). Terraform uses a `credential_process` profile because its SDK cannot read `aws login` sessions directly. Old key deactivated and verified rejected (InvalidClientTokenId); deletion after a soak period.

**F-03 — No IAM password policy (P6 teardown regression)**  
Account · Security · Medium · Remediated  
Policy set: 14+ characters, all four character classes, 24-password reuse prevention, no forced expiry (NIST SP 800-63B).

**F-04 — Site bucket publicly readable - Block Public Access off, `Principal: *` policy, no OAC**  
P1 · Security · High · Remediated  
Direct S3 returned 200 before. Now: S3 REST origin with Origin Access Control, policy scoped to the distribution ARN plus DenyInsecureTransport, all four BPA flags on. After: website endpoint 404, direct object 403, CloudFront 200, policy IsPublic=False.

**F-05 — CloudFront-to-S3 hop over HTTP (website endpoint is http-only)**  
P1 · Security · Medium · Remediated  
Fixed by the OAC change: HTTPS + SigV4 to the REST endpoint.

**F-06 — Single k3s node in one AZ; 1 GB swap is a workaround, not capacity**  
P5 · Reliability · High · Cost decision  
EKS control plane ~USD 73/month.

**F-07 — NodePort 30080 exposed directly; no ingress or TLS**  
P5 · Security · Medium · Design finding

**F-08 — RPO based on a single 26s replication sample; S3 RTC (paid) not used**  
P7 · Reliability · Medium · Design finding

**F-09 — One-way replication - failback is manual and has no runbook**  
P7 · Reliability · Medium · Design finding

**F-10 — Teardown-after-demo convention with independent CLI verification**  
Portfolio · Operational Excellence · n/a · Strength  
Held for P2, P3, P5, P6 and P7 (confirmed by the direct-API sweep). Broken once - see F-36.

**F-11 — Zero-spend outcome across seven projects**  
Portfolio · Cost Optimization, Sustainability · n/a · Strength  
October invoice USD 0.00.

**F-12 — SSH (22) open to 0.0.0.0/0 on the web tier**  
P2 · Security · High · Design finding  
Free fix: SSM Session Manager via instance profile; close port 22.

**F-13 — DB credentials hardcoded on EC2 and exposed through `outputs.tf` / state**  
P2 · Security · High · Design finding  
Free fix: instance-profile role + SSM Parameter Store SecureString (standard tier) instead of Secrets Manager (USD 0.40/secret/month).

**F-14 — RDS not encrypted at rest; TLS not enforced**  
P2 · Security · Medium · Design finding  
Encryption at rest is free - a missed free control, not a cost trade-off.

**F-15 — Web tier serves HTTP only**  
P2 · Security · Medium · Design finding

**F-16 — Built on Amazon Linux 2, which reached end of support on 2026-06-30**  
P2 · Operational Excellence, Security · Medium · Design finding  
Redeploy target: AL2023.

**F-17 — Single AZ: single web and app instances, no ALB/ASG, Single-AZ RDS**  
P2 · Reliability · High · Cost decision  
ALB ~USD 16/month, Multi-AZ doubles RDS cost.

**F-18 — NAT instance is a single point of failure with no auto-recovery**  
P2 · Reliability · Medium · Cost decision  
NAT Gateway ~USD 32/month.

**F-19 — No VPC Flow Logs, health monitoring or alarms**  
P2 · Operational Excellence, Security · Medium · Cost decision  
Flow Logs storage is not free.

**F-20 — P2 documentation predates portfolio conventions (no Components table, Known Limitations, teardown verification)**  
P2 · Operational Excellence · Low · Open  
Documentation backlog.

**F-21 — NAT instance over NAT Gateway (~USD 32/month) and Nginx over ALB (~USD 16/month)**  
P2 · Cost Optimization · n/a · Strength

**F-22 — 'What I Would Change for Production' section shows the trade-offs were understood**  
P2 · Operational Excellence · n/a · Strength

**F-23 — Pipeline design uses static AWS keys and an SSH private key in GitHub Secrets; no OIDC**  
P3 · Security · High · Design finding  
Current exposure none: the repo has no Actions secrets (verified). Free fix: GitHub OIDC + scoped IAM role.

**F-24 — Single EC2 deploy target**  
P3 · Reliability · n/a · Closed  
Merged into F-31.

**F-25 — Image registry/scanning unknown**  
P3 · Security · n/a · Closed  
Confirmed as F-32.

**F-26 — Test gate, container health test, deploy only on push to main, path filters**  
P3 · Operational Excellence · n/a · Strength

**F-27 — Suspected admin key stored in GitHub**  
P3 · Security · n/a · Closed  
Not confirmed - repository has no secrets.

**F-28 — Root console sign-in on 2026-10-20**  
Account · Security · Medium · Closed  
Reclassified as legitimate: Event History shows the session enabled MFA on root and on admin - root-only work. Led to F-65.

**F-29 — SSH deploy from GitHub-hosted runners implies port 22 open to the internet**  
P3 · Security · High · Design finding  
Runner IPs are dynamic. Free fix: SSM Run Command or pull-based deploy.

**F-30 — Tested artifact is not the deployed artifact**  
P3 · Operational Excellence, Reliability · Medium · Design finding  
CI builds and tests an image, discards it; the server rebuilds from `git pull`.

**F-31 — Stop/remove/run causes downtime on every deploy; no rollback image**  
P3 · Reliability · Medium · Design finding

**F-32 — No image vulnerability scan; third-party action pinned by tag, not commit SHA**  
P3 · Security · Medium · Design finding  
Trivy in Actions is free.

**F-33 — No `permissions:` block, so GITHUB_TOKEN gets default scopes**  
P3 · Security · Low · Design finding

**F-34 — Suspected failing pipeline: workflow triggers on push but its secrets are gone**  
P3 · Operational Excellence · n/a · Closed  
Not a gap: `ci-cd.yml` sits in `project-3-cicd-pipeline/.github/workflows/`, and GitHub only runs workflows from the repository root, so it never triggers in this repo. No change needed.

**F-35 — No IAM Access Analyzer (P6 teardown regression)**  
Account · Security · Medium · Remediated  
Account-level external-access analyzer (free) created; zero active findings, which also independently confirms the P1 bucket is no longer public.

**F-36 — Project 4 never destroyed - 21 resources live ~8 weeks**  
P4 · Operational Excellence, Cost Optimization · High · Remediated  
Lambda SQS event-source mapping polled 24/7 under `serverless-lambda-role` (found via the role's last-used date). Snapshot captured with `terraform show -json`, then `terraform destroy`, verified per service.

**F-37 — Retired SAM version left its `aws-sam-cli-managed-default` bootstrap stack**  
P4 · Operational Excellence, Cost Optimization · Low · Remediated  
Bucket emptied (all versions and delete markers), stack deleted, both verified gone.

**F-38 — One IAM role shared by all three functions; `logs` on `arn:aws:logs:*:*:*`**  
P4 · Security · Medium · Design finding  
`query` held SendMessage/PutItem it never used. Per-function roles are free.

**F-39 — No CloudWatch alarms, not even DLQ depth**  
P4 · Operational Excellence, Reliability · Medium · Design finding

**F-40 — Lambda log groups not Terraform-managed (never-expire retention) and orphaned by destroy**  
P4 · Operational Excellence, Cost Optimization · Medium · Remediated  
Deleted and verified. Code fix: `aws_cloudwatch_log_group` per function with `retention_in_days`.

**F-41 — Dead-letter queue with redrive (maxReceiveCount 3)**  
P4 · Reliability · n/a · Strength

**F-42 — All four HTTP API routes `authorization_type: NONE` - POST /ingest writable by anyone**  
P4 · Security · High · Design finding  
Exposed for the ~8 weeks of F-36. Exposure ended at teardown.

**F-43 — No stage throttling (0/0) - denial-of-wallet exposure combined with F-42**  
P4 · Reliability, Security, Cost Optimization · High · Design finding  
Stage throttling is free.

**F-44 — SQS visibility timeout (60s) equals process timeout (60s)**  
P4 · Reliability · Medium · Design finding  
AWS guidance: at least 6x the function timeout.

**F-45 — No `ReportBatchItemFailures` - one bad message retries the whole batch of 10**  
P4 · Reliability · Medium · Design finding

**F-46 — DLQ retention (4 days) equals source queue retention**  
P4 · Reliability · Low · Design finding  
Dead letters can expire soon after arriving.

**F-47 — No API access logs, detailed metrics or X-Ray tracing (PassThrough)**  
P4 · Operational Excellence · Medium · Design finding

**F-48 — /stats uses DynamoDB Scan - cost and latency grow with table size**  
P4 · Performance Efficiency, Cost Optimization · Low · Design finding

**F-49 — DynamoDB PITR off (paid); deletion protection off (free)**  
P4 · Reliability · Low · Cost decision

**F-50 — x86_64 Lambdas**  
P4 · Cost Optimization, Sustainability · Low · Design finding  
arm64 (Graviton) is ~20% cheaper per GB-second; no migration cost for pure Python.

**F-51 — No reserved concurrency**  
P4 · Reliability · Low · Design finding

**F-52 — Versioned SAM bucket kept 8 noncurrent versions behind delete markers**  
P4 · Cost Optimization, Sustainability · Low · Remediated  
No lifecycle rule, so 'deleted' data was still stored. Removed with the stack; fix pattern: `NoncurrentVersionExpiration`.

**F-53 — Resource Explorer index was stale and partial**  
Portfolio · Operational Excellence · Medium · Lesson  
Still listed P4's deleted API and 8 IAM roles (6 existed); only LOCAL indexes, no aggregator, so us-west-2 was unswept. Teardown checks now use direct service APIs (`scripts/sweep.sh`).

**F-54 — Direct bucket reads bypassed CloudFront caching and free tier**  
P1 · Cost Optimization · Low · Remediated  
Fixed by OAC.

**F-55 — Minimum viewer TLS is TLSv1 on the default *.cloudfront.net certificate**  
P1 · Security · Low · Cost decision  
TLSv1.2+ needs a custom domain and ACM certificate; a domain is not free.

**F-56 — CloudFront access logging off**  
P1 · Operational Excellence · Low · Cost decision  
Log storage is not free at zero spend.

**F-57 — Bucket versioning not enabled**  
P1 · Reliability · Low · Cost decision  
Accepted: site content is in Git and redeployed by Terraform.

**F-58 — HTTP/2 only**  
P1 · Performance Efficiency · Low · Remediated  
`http_version = http2and3`; `alt-svc: h3` verified.

**F-59 — No .tfstate or .tfvars file ever committed (current tree and full history)**  
Repo · Security · n/a · Strength  
Matters because P2's state held the RDS password in plaintext (F-13).

**F-60 — `*tfplan*` not ignored; stray empty `terraform.tfstate` at repo root**  
Repo · Security, Operational Excellence · Low · Remediated  
Saved plans embed state values. Pattern enabled in root .gitignore; stray file removed.

**F-61 — October raw usage USD 0.017**  
Account · Cost Optimization · Low · Closed  
Invoice shows USD 0.00 (Free Plan credits). Most likely source: the P4 leftover (F-36), now removed.

**F-62 — Monthly budget with ACTUAL 80%/100% and FORECASTED 100% email alerts**  
Account · Cost Optimization · n/a · Strength

**F-63 — Budget threshold too loose for a zero-spend account**  
Account · Cost Optimization · Low · Remediated  
First alert fired at USD 4 (80% of 5), so a leftover could cost dollars silently. Added an ACTUAL > USD 0.01 alert to the existing budget.

**F-64 — Account ID never present in tracked files or git history**  
Repo · Security · n/a · Strength  
WA Tool PDF reports contain the account ID and workload ARN, so they are git-ignored; evidence is published sanitized.

**F-65 — Root console session left signed in ~12 hours**  
Account · Security · Medium · Lesson  
Event History shows root's console polling notifications every 4 minutes overnight after the MFA setup. Root sessions cannot be shortened by policy - habit: sign out of root immediately after the root-only task.

**F-66 — IAM Identity Center not adopted**  
Account · Security, Cost Optimization · Medium · Cost decision  
Identity Center is free, but enabling it creates an AWS Organization, which moves the account from the Free Plan to pay-as-you-go and expires remaining credits (console warning). `aws login` short-lived credentials used instead (F-02).

**F-67 — Viewer HTTPS redirect, SSE-S3, compression, PriceClass_100**  
P1 · Security, Performance Efficiency, Cost Optimization · n/a · Strength

**F-68 — SQS SSE on both queues; IAM scoped to specific queue/table ARNs; DynamoDB encrypted**  
P4 · Security · n/a · Strength

**F-69 — Root has MFA and no access keys; admin has MFA**  
Account · Security · n/a · Strength
