#!/usr/bin/env bash
# Verify a published P11 image from outside GitHub Actions.
#   bash verify-image.sh sha256:<digest>
# Checks: the image is publicly pullable; the signature is valid only for this repository's P11 workflow on main
# (two wrong identities must be rejected); the CycloneDX SBOM attestation verifies. Needs cosign and python3.
set -uo pipefail
DIGEST=${1:?usage: verify-image.sh sha256:<digest>}
IMAGE=ghcr.io/zeiadalomari/cloud-portfolio/p11-app
REF="${IMAGE}@${DIGEST}"
REPO=https://github.com/ZeiadAlOmari/cloud-portfolio
GOOD_ID="${REPO}/.github/workflows/p11-supply-chain.yml@refs/heads/main"
ISSUER=https://token.actions.githubusercontent.com
COSIGN=${COSIGN:-cosign}
fail=0
ok()  { echo "  PASS  $*"; }
bad() { echo "  FAIL  $*"; fail=1; }

echo "== image: ${REF}"
echo "== cosign: $(${COSIGN} version 2>&1 | awk '/GitVersion/{print $2}')"

echo "== 1. anonymous pull access (public package)"
TOKEN=$(curl -s "https://ghcr.io/token?scope=repository:zeiadalomari/cloud-portfolio/p11-app:pull" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("token",""))')
CODE=$(curl -s -o /dev/null -w '%{http_code}' -I -H "Authorization: Bearer ${TOKEN}" \
  -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "https://ghcr.io/v2/zeiadalomari/cloud-portfolio/p11-app/manifests/${DIGEST}")
[ "${CODE}" = 200 ] && ok "manifest readable without credentials (HTTP ${CODE})" || bad "manifest not readable anonymously (HTTP ${CODE}); is the package public?"

echo "== 2. signature from the P11 workflow on main"
if OUT=$(${COSIGN} verify --certificate-identity "${GOOD_ID}" --certificate-oidc-issuer "${ISSUER}" "${REF}" 2>/dev/null); then
  ok "signature verified for ${GOOD_ID}"
  echo "${OUT}" | python3 -c '
import sys, json
entries = json.load(sys.stdin)
digests = sorted({e.get("critical", {}).get("image", {}).get("docker-manifest-digest") for e in entries})
print("        signed entries:", len(entries), "(image signature and SBOM attestation), all for digest", " ".join(d for d in digests if d))
' 2>/dev/null || true
else
  bad "signature did not verify for ${GOOD_ID}"
fi

echo "== 3. wrong identities must be rejected"
for WRONG in "${REPO}/.github/workflows/p1-terraform.yml@refs/heads/main" \
             "${REPO}/.github/workflows/p11-supply-chain.yml@refs/heads/attacker-branch"; do
  if ${COSIGN} verify --certificate-identity "${WRONG}" --certificate-oidc-issuer "${ISSUER}" "${REF}" >/dev/null 2>&1; then
    bad "accepted wrong identity ${WRONG}"
  else
    ok "rejected ${WRONG#${REPO}/}"
  fi
done

echo "== 4. SBOM attestation (CycloneDX)"
if OUT=$(${COSIGN} verify-attestation --type cyclonedx --certificate-identity "${GOOD_ID}" --certificate-oidc-issuer "${ISSUER}" "${REF}" 2>/dev/null); then
  ok "SBOM attestation verified"
  echo "${OUT}" | python3 -c '
import sys, json, base64
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    st = json.loads(base64.b64decode(json.loads(line)["payload"]))
    comps = st.get("predicate", {}).get("components", [])
    names = sorted(c.get("name", "") + "==" + c.get("version", "") for c in comps if c.get("type") == "library" and "pypi" in c.get("purl", ""))
    print("        predicate type:", st.get("predicateType")); print("        components:", len(comps))
    print("        python packages:", ", ".join(names)); break
' 2>/dev/null || true
else
  bad "SBOM attestation did not verify"
fi

echo "== result: $([ ${fail} = 0 ] && echo 'ALL CHECKS PASSED' || echo 'SOME CHECKS FAILED')"
exit ${fail}
