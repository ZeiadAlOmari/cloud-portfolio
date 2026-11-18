#!/usr/bin/env bash
# Copy evidence/raw/*.txt (git-ignored) to evidence/ with identifying values redacted:
# AWS account ID, e-mail addresses, IPv4 addresses, IAM unique role IDs and access key IDs.
# Usage: bash scripts/sanitize-evidence.sh   (any working directory)
set -euo pipefail
cd "$(dirname "$0")/.."
ACCT=$(grep -ohE 'arn:aws:[a-z0-9-]+:[a-z0-9-]*:[0-9]{12}' evidence/raw/*.txt | grep -oE '[0-9]{12}$' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}' || true)
[ -n "$ACCT" ] || ACCT=$(aws sts get-caller-identity --query Account --output text)
[ -n "$ACCT" ] || { echo "could not determine account ID"; exit 1; }
n=0
for f in evidence/raw/*.txt; do
  sed -E "s/${ACCT}/<ACCOUNT_ID>/g
          s/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z.]{2,}/<EMAIL>/g
          s/\b([0-9]{1,3}\.){3}[0-9]{1,3}\b/<IP>/g
          s/\bAROA[A-Z0-9]{12,}/<ROLE_ID>/g
          s/\b(AKIA|ASIA)[A-Z0-9]{16}\b/<ACCESS_KEY_ID>/g" "$f" > "evidence/$(basename "$f")"
  n=$((n + 1))
done
leaks=$(grep -lE "${ACCT}|AROA[A-Z0-9]{12,}|(AKIA|ASIA)[A-Z0-9]{16}|[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z]{2,}|\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" evidence/*.txt || true)
[ -z "$leaks" ] || { echo "LEAK in: $leaks"; exit 1; }
echo "sanitized $n files; account ID, e-mail, IP, role ID and key ID present in published evidence: 0"
