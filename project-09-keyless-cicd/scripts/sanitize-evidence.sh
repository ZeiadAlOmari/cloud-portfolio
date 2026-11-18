#!/usr/bin/env bash
# Copy evidence/raw/*.txt (git-ignored) to evidence/ with the AWS account ID redacted.
# Usage: bash scripts/sanitize-evidence.sh   (any working directory)
set -euo pipefail
cd "$(dirname "$0")/.."
ACCT=$(grep -oE 'arn:aws:iam::[0-9]{12}' evidence/raw/01-bootstrap-outputs.txt | head -1 | grep -oE '[0-9]{12}')
[ -n "$ACCT" ] || { echo "could not read account ID"; exit 1; }
n=0
for f in evidence/raw/*.txt; do
  sed -E "s/${ACCT}/<ACCOUNT_ID>/g; s/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z.]{2,}/<EMAIL>/g" "$f" > "evidence/$(basename "$f")"
  n=$((n + 1))
done
if grep -rl "$ACCT" evidence --include='*.txt' --exclude-dir=raw; then echo "LEAK: account ID still present"; exit 1; fi
echo "sanitized $n files; account ID present in published evidence: 0"
