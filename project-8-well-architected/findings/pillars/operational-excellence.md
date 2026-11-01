# Operational Excellence

Findings tagged **Operational Excellence** (primary or secondary). Full register: [`../findings-register.md`](../findings-register.md).

| Status | Count |
|---|---|
| Remediated | 4 |
| Cost decision | 2 |
| Design finding | 4 |
| Lesson | 1 |
| Open | 1 |
| Closed | 1 |
| Strength | 3 |

## Remediated

- **F-36** (P4, 🔴 High, `decomissioning-resources`) — Project 4 never destroyed - 21 resources live ~8 weeks. Lambda SQS event-source mapping polled 24/7 under `serverless-lambda-role` (found via the role's last-used date). Snapshot captured with `terraform show -json`, then `terraform destroy`, verified per service. _Evidence: 04, 05, 06, 07, 08, 09_
- **F-40** (P4, 🟠 Medium, `decomissioning-resources`) — Lambda log groups not Terraform-managed (never-expire retention) and orphaned by destroy. Deleted and verified. Code fix: `aws_cloudwatch_log_group` per function with `retention_in_days`. _Evidence: 09, 10_
- **F-37** (P4, 🟡 Low, `decomissioning-resources`) — Retired SAM version left its `aws-sam-cli-managed-default` bootstrap stack. Bucket emptied (all versions and delete markers), stack deleted, both verified gone. _Evidence: 06, 11, 12, 13_
- **F-60** (Repo, 🟡 Low, `dev-integ`) — `*tfplan*` not ignored; stray empty `terraform.tfstate` at repo root. Saved plans embed state values. Pattern enabled in root .gitignore; stray file removed. _Evidence: 06, 17, 34_

## Cost decision

- **F-19** (P2, 🟠 Medium, `monitor-aws-resources`) — No VPC Flow Logs, health monitoring or alarms. Flow Logs storage is not free. _Evidence: P2 docs_
- **F-56** (P1, 🟡 Low, `workload-observability`) — CloudFront access logging off. Log storage is not free at zero spend. _Evidence: 15_

## Design finding

- **F-16** (P2, 🟠 Medium, `dev-integ`) — Built on Amazon Linux 2, which reached end of support on 2026-06-30. Redeploy target: AL2023. _Evidence: P2 docs_
- **F-30** (P3, 🟠 Medium, `dev-integ`) — Tested artifact is not the deployed artifact. CI builds and tests an image, discards it; the server rebuilds from `git pull`. _Evidence: P3 workflow_
- **F-39** (P4, 🟠 Medium, `monitor-aws-resources`) — No CloudWatch alarms, not even DLQ depth _Evidence: 07, 08_
- **F-47** (P4, 🟠 Medium, `observability`) — No API access logs, detailed metrics or X-Ray tracing (PassThrough) _Evidence: 08_

## Lesson

- **F-53** (Portfolio, 🟠 Medium, `decomissioning-resources`) — Resource Explorer index was stale and partial. Still listed P4's deleted API and 8 IAM roles (6 existed); only LOCAL indexes, no aggregator, so us-west-2 was unswept. Teardown checks now use direct service APIs (`scripts/sweep.sh`). _Evidence: 13, 14_

## Open

- **F-20** (P2, 🟡 Low, `dev-integ`) — P2 documentation predates portfolio conventions (no Components table, Known Limitations, teardown verification). Documentation backlog. _Evidence: P2 docs_

## Closed

- **F-34** (P3, 🟢 —, `mit-deploy-risks`) — Suspected failing pipeline: workflow triggers on push but its secrets are gone. Not a gap: `ci-cd.yml` sits in `project-3-cicd-pipeline/.github/workflows/`, and GitHub only runs workflows from the repository root, so it never triggers in this repo. No change needed. _Evidence: 34_

## Strength

- **F-10** (Portfolio, 🟢 —, `decomissioning-resources`) — Teardown-after-demo convention with independent CLI verification. Held for P2, P3, P5, P6 and P7 (confirmed by the direct-API sweep). Broken once - see F-36. _Evidence: 14_
- **F-22** (P2, 🟢 —, `evolve-ops`) — 'What I Would Change for Production' section shows the trade-offs were understood _Evidence: P2 docs_
- **F-26** (P3, 🟢 —, `dev-integ`) — Test gate, container health test, deploy only on push to main, path filters _Evidence: P3 workflow_
