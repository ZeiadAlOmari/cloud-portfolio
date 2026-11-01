# Reliability

Findings tagged **Reliability** (primary or secondary). Full register: [`../findings-register.md`](../findings-register.md).

| Status | Count |
|---|---|
| Cost decision | 5 |
| Design finding | 10 |
| Closed | 1 |
| Strength | 1 |

## Cost decision

- **F-06** (P5, 🔴 High, `fault-isolation`) — Single k3s node in one AZ; 1 GB swap is a workaround, not capacity. EKS control plane ~USD 73/month. _Evidence: P5 docs_
- **F-17** (P2, 🔴 High, `fault-isolation`) — Single AZ: single web and app instances, no ALB/ASG, Single-AZ RDS. ALB ~USD 16/month, Multi-AZ doubles RDS cost. _Evidence: P2 docs_
- **F-18** (P2, 🟠 Medium, `withstand-component-failures`) — NAT instance is a single point of failure with no auto-recovery. NAT Gateway ~USD 32/month. _Evidence: P2 docs_
- **F-49** (P4, 🟡 Low, `backing-up-data`) — DynamoDB PITR off (paid); deletion protection off (free) _Evidence: 08_
- **F-57** (P1, 🟡 Low, `backing-up-data`) — Bucket versioning not enabled. Accepted: site content is in Git and redeployed by Terraform. _Evidence: 15_

## Design finding

- **F-43** (P4, 🔴 High, `mitigate-interaction-failure`) — No stage throttling (0/0) - denial-of-wallet exposure combined with F-42. Stage throttling is free. _Evidence: 08_
- **F-08** (P7, 🟠 Medium, `planning-for-recovery`) — RPO based on a single 26s replication sample; S3 RTC (paid) not used _Evidence: P7 docs_
- **F-09** (P7, 🟠 Medium, `planning-for-recovery`) — One-way replication - failback is manual and has no runbook _Evidence: P7 docs_
- **F-30** (P3, 🟠 Medium, `dev-integ`) — Tested artifact is not the deployed artifact. CI builds and tests an image, discards it; the server rebuilds from `git pull`. _Evidence: P3 workflow_
- **F-31** (P3, 🟠 Medium, `mit-deploy-risks`) — Stop/remove/run causes downtime on every deploy; no rollback image _Evidence: P3 workflow_
- **F-39** (P4, 🟠 Medium, `monitor-aws-resources`) — No CloudWatch alarms, not even DLQ depth _Evidence: 07, 08_
- **F-44** (P4, 🟠 Medium, `prevent-interaction-failure`) — SQS visibility timeout (60s) equals process timeout (60s). AWS guidance: at least 6x the function timeout. _Evidence: 08_
- **F-45** (P4, 🟠 Medium, `mitigate-interaction-failure`) — No `ReportBatchItemFailures` - one bad message retries the whole batch of 10 _Evidence: 08_
- **F-46** (P4, 🟡 Low, `mitigate-interaction-failure`) — DLQ retention (4 days) equals source queue retention. Dead letters can expire soon after arriving. _Evidence: 08_
- **F-51** (P4, 🟡 Low, `mitigate-interaction-failure`) — No reserved concurrency _Evidence: 08_

## Closed

- **F-24** (P3, 🟢 —, `mit-deploy-risks`) — Single EC2 deploy target. Merged into F-31.

## Strength

- **F-41** (P4, 🟢 —, `mitigate-interaction-failure`) — Dead-letter queue with redrive (maxReceiveCount 3) _Evidence: 08_
