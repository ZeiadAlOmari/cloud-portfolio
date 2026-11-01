# Security

Findings tagged **Security** (primary or secondary). Full register: [`../findings-register.md`](../findings-register.md).

| Status | Count |
|---|---|
| Remediated | 6 |
| Cost decision | 4 |
| Design finding | 13 |
| Lesson | 1 |
| Closed | 3 |
| Strength | 5 |

## Remediated

- **F-02** (Account, 🔴 High, `identities`) — Admin IAM user (AdministratorAccess) used via a 68-day-old long-lived access key. CLI moved to `aws login` (browser sign-in with MFA, temporary ASIA credentials). Terraform uses a `credential_process` profile because its SDK cannot read `aws login` sessions directly. Old key deactivated and verified rejected (InvalidClientTokenId); deleted 2026-11-01 after a 5-day soak (admin has 0 access keys). _Evidence: 00, 01, 30, 31, 32_
- **F-04** (P1, 🔴 High, `protect-data-rest`) — Site bucket publicly readable - Block Public Access off, `Principal: *` policy, no OAC. Direct S3 returned 200 before. Now: S3 REST origin with Origin Access Control, policy scoped to the distribution ARN plus DenyInsecureTransport, all four BPA flags on. After: website endpoint 404, direct object 403, CloudFront 200, policy IsPublic=False. _Evidence: 15, 16, 18, 19_
- **F-03** (Account, 🟠 Medium, `identities`) — No IAM password policy (P6 teardown regression). Policy set: 14+ characters, all four character classes, 24-password reuse prevention, no forced expiry (NIST SP 800-63B). _Evidence: 02, 20_
- **F-05** (P1, 🟠 Medium, `protect-data-transit`) — CloudFront-to-S3 hop over HTTP (website endpoint is http-only). Fixed by the OAC change: HTTPS + SigV4 to the REST endpoint. _Evidence: 15, 19_
- **F-35** (Account, 🟠 Medium, `permissions`) — No IAM Access Analyzer (P6 teardown regression). Account-level external-access analyzer (free) created; zero active findings, which also independently confirms the P1 bucket is no longer public. _Evidence: 02, 21_
- **F-60** (Repo, 🟡 Low, `dev-integ`) — `*tfplan*` not ignored; stray empty `terraform.tfstate` at repo root. Saved plans embed state values. Pattern enabled in root .gitignore; stray file removed. _Evidence: 06, 17, 34_

## Cost decision

- **F-01** (Account, 🔴 High, `detect-investigate-events`) — No CloudTrail trail - Project 6 teardown removed it. Tearing down P6 deleted the account-level trail with the project stack. A trail is free but its S3 delivery is not; the free 90-day CloudTrail Event History is the compensating control and was verified recording every remediation call (and answered F-28). _Evidence: 02, 22, 27_
- **F-19** (P2, 🟠 Medium, `monitor-aws-resources`) — No VPC Flow Logs, health monitoring or alarms. Flow Logs storage is not free. _Evidence: P2 docs_
- **F-66** (Account, 🟠 Medium, `identities`) — IAM Identity Center not adopted. Identity Center is free, but enabling it creates an AWS Organization, which moves the account from the Free Plan to pay-as-you-go and expires remaining credits (console warning). `aws login` short-lived credentials used instead (F-02). _Evidence: 30_
- **F-55** (P1, 🟡 Low, `protect-data-transit`) — Minimum viewer TLS is TLSv1 on the default *.cloudfront.net certificate. TLSv1.2+ needs a custom domain and ACM certificate; a domain is not free. _Evidence: 15_

## Design finding

- **F-12** (P2, 🔴 High, `network-protection`) — SSH (22) open to 0.0.0.0/0 on the web tier. Free fix: SSM Session Manager via instance profile; close port 22. _Evidence: P2 docs_
- **F-13** (P2, 🔴 High, `identities`) — DB credentials hardcoded on EC2 and exposed through `outputs.tf` / state. Free fix: instance-profile role + SSM Parameter Store SecureString (standard tier) instead of Secrets Manager (USD 0.40/secret/month). _Evidence: P2 docs_
- **F-23** (P3, 🔴 High, `application-security`) — Pipeline design uses static AWS keys and an SSH private key in GitHub Secrets; no OIDC. Current exposure none: the repo has no Actions secrets (verified). Free fix: GitHub OIDC + scoped IAM role. _Evidence: 03, P3 workflow_
- **F-29** (P3, 🔴 High, `network-protection`) — SSH deploy from GitHub-hosted runners implies port 22 open to the internet. Runner IPs are dynamic. Free fix: SSM Run Command or pull-based deploy. _Evidence: P3 workflow_
- **F-42** (P4, 🔴 High, `application-security`) — All four HTTP API routes `authorization_type: NONE` - POST /ingest writable by anyone. Exposed for the ~8 weeks of F-36. Exposure ended at teardown. _Evidence: 08_
- **F-43** (P4, 🔴 High, `mitigate-interaction-failure`) — No stage throttling (0/0) - denial-of-wallet exposure combined with F-42. Stage throttling is free. _Evidence: 08_
- **F-07** (P5, 🟠 Medium, `network-protection`) — NodePort 30080 exposed directly; no ingress or TLS _Evidence: P5 docs_
- **F-14** (P2, 🟠 Medium, `protect-data-rest`) — RDS not encrypted at rest; TLS not enforced. Encryption at rest is free - a missed free control, not a cost trade-off. _Evidence: P2 docs_
- **F-15** (P2, 🟠 Medium, `protect-data-transit`) — Web tier serves HTTP only _Evidence: P2 docs_
- **F-16** (P2, 🟠 Medium, `dev-integ`) — Built on Amazon Linux 2, which reached end of support on 2026-06-30. Redeploy target: AL2023. _Evidence: P2 docs_
- **F-32** (P3, 🟠 Medium, `protect-compute`) — No image vulnerability scan; third-party action pinned by tag, not commit SHA. Trivy in Actions is free. _Evidence: P3 workflow_
- **F-38** (P4, 🟠 Medium, `permissions`) — One IAM role shared by all three functions; `logs` on `arn:aws:logs:*:*:*`. `query` held SendMessage/PutItem it never used. Per-function roles are free. _Evidence: 08_
- **F-33** (P3, 🟡 Low, `application-security`) — No `permissions:` block, so GITHUB_TOKEN gets default scopes _Evidence: P3 workflow_

## Lesson

- **F-65** (Account, 🟠 Medium, `securely-operate`) — Root console session left signed in ~12 hours. Event History shows root's console polling notifications every 4 minutes overnight after the MFA setup. Root sessions cannot be shortened by policy - habit: sign out of root immediately after the root-only task. _Evidence: 27_

## Closed

- **F-28** (Account, 🟠 Medium, `securely-operate`) — Root console sign-in on 2026-10-20. Reclassified as legitimate: Event History shows the session enabled MFA on root and on admin - root-only work. Led to F-65. _Evidence: 01, 27_
- **F-25** (P3, 🟢 —, `protect-compute`) — Image registry/scanning unknown. Confirmed as F-32.
- **F-27** (P3, 🟢 —, `identities`) — Suspected admin key stored in GitHub. Not confirmed - repository has no secrets. _Evidence: 03_

## Strength

- **F-59** (Repo, 🟢 —, `securely-operate`) — No .tfstate or .tfvars file ever committed (current tree and full history). Matters because P2's state held the RDS password in plaintext (F-13). _Evidence: 17_
- **F-64** (Repo, 🟢 —, `securely-operate`) — Account ID never present in tracked files or git history. WA Tool PDF reports contain the account ID and workload ARN, so they are git-ignored; evidence is published sanitized.
- **F-67** (P1, 🟢 —, `protect-data-transit`) — Viewer HTTPS redirect, SSE-S3, compression, PriceClass_100 _Evidence: 15_
- **F-68** (P4, 🟢 —, `protect-data-rest`) — SQS SSE on both queues; IAM scoped to specific queue/table ARNs; DynamoDB encrypted _Evidence: 08_
- **F-69** (Account, 🟢 —, `securely-operate`) — Root has MFA and no access keys; admin has MFA _Evidence: 01_
