#!/usr/bin/env bash
# Copy evidence/raw/* (git-ignored) to evidence/ with account identifiers redacted.
# Usage: bash scripts/sanitize-evidence.sh   (run from project-8-well-architected/)
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY'
import glob, json, os, re, shutil

RAW, OUT = "evidence/raw", "evidence"
acct = json.load(open(f"{RAW}/00-caller-identity.json"))["Account"]
wl = open(f"{RAW}/23-wa-workload-id.txt").read().strip() if os.path.exists(f"{RAW}/23-wa-workload-id.txt") else None
SKIP = {"08-p4-show.json", "23-wa-workload-id.txt"}          # full state dump / bare workload id
SKIP_GLOB = ("24-wa-",)                                        # raw lens exports (large, no review value)

subs = [
    (re.compile(re.escape(acct)), "<ACCOUNT_ID>"),
    (re.compile(r"\b(AIDA|AROA|AKIA|ASIA)[A-Z0-9]{12,}\b"), r"\1<REDACTED>"),
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), "<EMAIL>"),
]
if wl: subs.append((re.compile(re.escape(wl)), "<WORKLOAD_ID>"))

def clean(t):
    for rx, rep in subs: t = rx.sub(rep, t)
    return t

n = 0
for p in sorted(glob.glob(f"{RAW}/*")):
    name = os.path.basename(p)
    if name in SKIP or name.startswith(SKIP_GLOB): continue
    if name.lower().endswith((".png", ".jpg")):
        shutil.copy(p, f"{OUT}/{name}"); n += 1; continue
    open(f"{OUT}/{name}", "w").write(clean(open(p, errors="replace").read())); n += 1

# P4 configuration summary from the pre-destroy state snapshot
src = f"{RAW}/08-p4-show.json"
if os.path.exists(src):
    R = json.load(open(src))["values"]["root_module"]["resources"]
    K = {"aws_lambda_function": ["function_name","memory_size","timeout","reserved_concurrent_executions","tracing_config","architectures"],
         "aws_dynamodb_table": ["name","billing_mode","point_in_time_recovery","server_side_encryption","deletion_protection_enabled"],
         "aws_sqs_queue": ["name","visibility_timeout_seconds","message_retention_seconds","sqs_managed_sse_enabled"],
         "aws_sqs_queue_redrive_policy": ["redrive_policy"],
         "aws_apigatewayv2_stage": ["name","default_route_settings","access_log_settings"],
         "aws_apigatewayv2_route": ["route_key","authorization_type"],
         "aws_iam_role_policy": ["policy"],
         "aws_lambda_event_source_mapping": ["batch_size","function_response_types","scaling_config"]}
    lines = ["# P4 configuration captured with `terraform show -json` before `terraform destroy` (2026-10-26)"]
    lines += [f"{r['type']} {json.dumps({k: r['values'].get(k) for k in K[r['type']]})}" for r in R if r["type"] in K]
    open(f"{OUT}/08-p4-config-summary.txt", "w").write(clean("\n".join(lines) + "\n")); n += 1

leaks = [f for f in glob.glob(f"{OUT}/*") if os.path.isfile(f) and not f.endswith((".png", ".jpg"))
         and acct in open(f, errors="replace").read()]
if leaks: raise SystemExit(f"LEAK: account ID still present in {leaks}")
print(f"sanitized {n} files; account ID present in published evidence: 0")
PY
