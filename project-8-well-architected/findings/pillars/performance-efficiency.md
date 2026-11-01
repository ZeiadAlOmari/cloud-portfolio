# Performance Efficiency

Findings tagged **Performance Efficiency** (primary or secondary). Full register: [`../findings-register.md`](../findings-register.md).

| Status | Count |
|---|---|
| Remediated | 1 |
| Design finding | 1 |
| Strength | 1 |

## Remediated

- **F-58** (P1, 🟡 Low, `networking`) — HTTP/2 only. `http_version = http2and3`; `alt-svc: h3` verified. _Evidence: 19_

## Design finding

- **F-48** (P4, 🟡 Low, `data-management`) — /stats uses DynamoDB Scan - cost and latency grow with table size _Evidence: 08_

## Strength

- **F-67** (P1, 🟢 —, `protect-data-transit`) — Viewer HTTPS redirect, SSE-S3, compression, PriceClass_100 _Evidence: 15_
