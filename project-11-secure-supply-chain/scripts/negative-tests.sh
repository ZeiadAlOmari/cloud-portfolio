#!/usr/bin/env bash
# P11 negative tests: show what the deploy path refuses. Run as an admin with the live stack up.
#   bash scripts/negative-tests.sh        (from project-11-secure-supply-chain/)
# 1. An unsigned digest from the trusted repository is refused by the instance itself (old app keeps running).
# 2. A malformed or injected "digest" is rejected by SSM before anything runs.
# 3. The CI role may run only p11-deploy, on P11-tagged instances: not AWS-RunShellScript, not other instances.
set -uo pipefail
cd "$(dirname "$0")/.."
IID=$(terraform -chdir=terraform output -raw instance_id)
URL=$(terraform -chdir=terraform output -raw url)
REPO=zeiadalomari/cloud-portfolio/p11-app
ACCT=$(aws sts get-caller-identity --query Account --output text)
fail=0
ok()  { echo "  PASS  $*"; }
bad() { echo "  FAIL  $*"; fail=1; }
running() { curl -s -m 10 "${URL}/" | python3 -c 'import sys,json;print(json.load(sys.stdin)["image_digest"])' 2>/dev/null; }
wait_cmd() {  # $1 command id -> prints final status
  local s
  for _ in $(seq 1 40); do
    s=$(aws ssm get-command-invocation --command-id "$1" --instance-id "${IID}" --query Status --output text 2>/dev/null || echo Pending)
    case "$s" in Pending|InProgress|Delayed) sleep 5 ;; *) echo "$s"; return ;; esac
  done
  echo "$s"
}

BEFORE=$(running)
echo "== running before tests: ${BEFORE}"

echo "== 1. unsigned digest from the same repository"
TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:${REPO}:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
ACCEPT='application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json'
# Signature/attestation artifacts live in the same repository; they have digests but no signature of their own.
TAG=$(curl -s -H "Authorization: Bearer ${TOKEN}" "https://ghcr.io/v2/${REPO}/tags/list" | python3 -c 'import sys,json;t=[x for x in json.load(sys.stdin).get("tags",[]) if x.startswith("sha256-")];print(t[0] if t else "")')
if [ -n "${TAG}" ]; then
  UNSIGNED=$(curl -sI -H "Authorization: Bearer ${TOKEN}" -H "Accept: ${ACCEPT}" "https://ghcr.io/v2/${REPO}/manifests/${TAG}" | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}' | tr -d '\r')
  echo "        using artifact ${TAG} -> ${UNSIGNED} (exists in the trusted repo, never signed)"
else
  UNSIGNED="sha256:$(printf 'p11-unsigned-test' | sha256sum | cut -d' ' -f1)"
  echo "        no artifact tags listed; using a digest that was never signed: ${UNSIGNED}"
fi
CID=$(aws ssm send-command --document-name p11-deploy --instance-ids "${IID}" --parameters "Digest=${UNSIGNED}" \
      --comment "P11 negative test: unsigned" --query Command.CommandId --output text)
ST=$(wait_cmd "${CID}")
OUT=$(aws ssm get-command-invocation --command-id "${CID}" --instance-id "${IID}" --query StandardOutputContent --output text)
echo "        SSM status: ${ST}; instance said: $(echo "${OUT}" | grep -E 'REFUSED|verified' | head -2 | tr '\n' ' ')"
[ "${ST}" = "Failed" ] && echo "${OUT}" | grep -q REFUSED && ok "instance refused the unsigned digest" || bad "unsigned digest was not refused"
AFTER=$(running)
[ "${AFTER}" = "${BEFORE}" ] && ok "app untouched, still running ${AFTER}" || bad "running digest changed to ${AFTER}"

echo "== 2. malformed and injected digests"
for BADDIGEST in 'latest' 'sha256:abc' 'sha256:$(reboot)' "${BEFORE}; reboot"; do
  if ERR=$(aws ssm send-command --document-name p11-deploy --instance-ids "${IID}" --parameters "Digest=${BADDIGEST}" \
           --comment "P11 negative test: malformed" --query Command.CommandId --output text 2>&1); then
    bad "accepted '${BADDIGEST}' (command ${ERR})"
  else
    ok "rejected '${BADDIGEST}' before running: $(echo "${ERR}" | grep -oE '\(InvalidParameters\)|InvalidParameters' | head -1)"
  fi
done

echo "== 3. what the CI role is allowed to do (IAM policy simulator)"
ROLE="arn:aws:iam::${ACCT}:role/gha-p11-deploy"
sim() { # $1 resource ARN, $2 value of the instance's Project tag -> decision
  aws iam simulate-principal-policy --policy-source-arn "${ROLE}" --action-names ssm:SendCommand --resource-arns "$1" \
    --context-entries "ContextKeyName=ssm:resourceTag/Project,ContextKeyValues=$2,ContextKeyType=string" \
    --query 'EvaluationResults[0].EvalDecision' --output text
}
expect() { # $1 expected, $2 actual, $3 label
  [ "$2" = "$1" ] && ok "$3: $2" || bad "$3: $2 (expected $1)"
}
INST="arn:aws:ec2:us-east-1:${ACCT}:instance/${IID}"
expect allowed      "$(sim "arn:aws:ssm:us-east-1:${ACCT}:document/p11-deploy" p11-secure-supply-chain)" "run document p11-deploy"
expect implicitDeny "$(sim "arn:aws:ssm:us-east-1::document/AWS-RunShellScript" p11-secure-supply-chain)" "run AWS-RunShellScript (a full shell)"
expect allowed      "$(sim "${INST}" p11-secure-supply-chain)" "target an instance tagged Project=p11-secure-supply-chain"
expect implicitDeny "$(sim "${INST}" some-other-project)" "target an instance tagged for another project"

echo "== result: $([ ${fail} = 0 ] && echo 'ALL NEGATIVE TESTS PASSED' || echo 'SOME TESTS FAILED')"
exit ${fail}
