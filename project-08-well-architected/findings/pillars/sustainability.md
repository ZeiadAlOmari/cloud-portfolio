# Sustainability

Findings tagged **Sustainability** (primary or secondary). Full register: [`../findings-register.md`](../findings-register.md).

| Status | Count |
|---|---|
| Remediated | 2 |
| Strength | 1 |

## Remediated

- **F-50** (P4, 🟡 Low, `sus_hardware`) — x86_64 Lambdas. arm64 (Graviton) is ~20% cheaper per GB-second; no migration cost for pure Python. Fixed in Project 10 (rebuilt, verified live, then torn down): all three functions arm64. _Evidence: 08, P10_
- **F-52** (P4, 🟡 Low, `decomissioning-resources`) — Versioned SAM bucket kept 8 noncurrent versions behind delete markers. No lifecycle rule, so 'deleted' data was still stored. Removed with the stack; fix pattern: `NoncurrentVersionExpiration`. _Evidence: 11_

## Strength

- **F-11** (Portfolio, 🟢 —, `cloud-financial-management`) — Zero-spend outcome across seven projects. October invoice USD 0.00. _Evidence: 22_
