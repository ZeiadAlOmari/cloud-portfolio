# Cost Optimization

Findings tagged **Cost Optimization** (primary or secondary). Full register: [`../findings-register.md`](../findings-register.md).

| Status | Count |
|---|---|
| Remediated | 6 |
| Cost decision | 1 |
| Design finding | 3 |
| Closed | 1 |
| Strength | 4 |

## Remediated

- **F-36** (P4, 🔴 High, `decomissioning-resources`) — Project 4 never destroyed - 21 resources live ~8 weeks. Lambda SQS event-source mapping polled 24/7 under `serverless-lambda-role` (found via the role's last-used date). Snapshot captured with `terraform show -json`, then `terraform destroy`, verified per service. _Evidence: 04, 05, 06, 07, 08, 09_
- **F-40** (P4, 🟠 Medium, `decomissioning-resources`) — Lambda log groups not Terraform-managed (never-expire retention) and orphaned by destroy. Deleted and verified. Code fix: `aws_cloudwatch_log_group` per function with `retention_in_days`. _Evidence: 09, 10_
- **F-37** (P4, 🟡 Low, `decomissioning-resources`) — Retired SAM version left its `aws-sam-cli-managed-default` bootstrap stack. Bucket emptied (all versions and delete markers), stack deleted, both verified gone. _Evidence: 06, 11, 12, 13_
- **F-52** (P4, 🟡 Low, `decomissioning-resources`) — Versioned SAM bucket kept 8 noncurrent versions behind delete markers. No lifecycle rule, so 'deleted' data was still stored. Removed with the stack; fix pattern: `NoncurrentVersionExpiration`. _Evidence: 11_
- **F-54** (P1, 🟡 Low, `data-transfer`) — Direct bucket reads bypassed CloudFront caching and free tier. Fixed by OAC. _Evidence: 18, 19_
- **F-63** (Account, 🟡 Low, `cloud-financial-management`) — Budget threshold too loose for a zero-spend account. First alert fired at USD 4 (80% of 5), so a leftover could cost dollars silently. Added an ACTUAL > USD 0.01 alert to the existing budget. _Evidence: 22, 28_

## Cost decision

- **F-66** (Account, 🟠 Medium, `identities`) — IAM Identity Center not adopted. Identity Center is free, but enabling it creates an AWS Organization, which moves the account from the Free Plan to pay-as-you-go and expires remaining credits (console warning). `aws login` short-lived credentials used instead (F-02). _Evidence: 30_

## Design finding

- **F-43** (P4, 🔴 High, `mitigate-interaction-failure`) — No stage throttling (0/0) - denial-of-wallet exposure combined with F-42. Stage throttling is free. _Evidence: 08_
- **F-48** (P4, 🟡 Low, `data-management`) — /stats uses DynamoDB Scan - cost and latency grow with table size _Evidence: 08_
- **F-50** (P4, 🟡 Low, `sus_hardware`) — x86_64 Lambdas. arm64 (Graviton) is ~20% cheaper per GB-second; no migration cost for pure Python. _Evidence: 08_

## Closed

- **F-61** (Account, 🟡 Low, `cloud-financial-management`) — October raw usage USD 0.017. Invoice shows USD 0.00 (Free Plan credits). Most likely source: the P4 leftover (F-36), now removed. _Evidence: 22_

## Strength

- **F-11** (Portfolio, 🟢 —, `cloud-financial-management`) — Zero-spend outcome across seven projects. October invoice USD 0.00. _Evidence: 22_
- **F-21** (P2, 🟢 —, `select-service`) — NAT instance over NAT Gateway (~USD 32/month) and Nginx over ALB (~USD 16/month) _Evidence: P2 docs_
- **F-62** (Account, 🟢 —, `cloud-financial-management`) — Monthly budget with ACTUAL 80%/100% and FORECASTED 100% email alerts _Evidence: 22_
- **F-67** (P1, 🟢 —, `protect-data-transit`) — Viewer HTTPS redirect, SSE-S3, compression, PriceClass_100 _Evidence: 15_
