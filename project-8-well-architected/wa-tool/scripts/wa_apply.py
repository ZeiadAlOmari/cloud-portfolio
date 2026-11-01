#!/usr/bin/env python3
"""Project 8 - apply Well-Architected answers and create milestones.

Usage (from project-8-well-architected/):
  python3 wa-tool/scripts/wa_apply.py baseline   # set all answers (pre-remediation), create Milestone 1
  python3 wa-tool/scripts/wa_apply.py post       # apply post-remediation changes, create Milestone 2, export PDFs
"""
import base64, json, subprocess, sys

REGION = "us-east-1"
W = open("evidence/raw/23-wa-workload-id.txt").read().strip()
A = json.load(open("wa-tool/answers.json"))
LENSES = ["wellarchitected", "serverless"]


def aws(*args):
    out = subprocess.run(["aws", "wellarchitected", *args, "--region", REGION, "--output", "json"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit("AWS ERROR: " + out.stderr.strip())
    return json.loads(out.stdout) if out.stdout.strip() else {}


def set_answer(lens, qid, choices, note):
    aws("update-answer", "--workload-id", W, "--lens-alias", lens, "--question-id", qid,
        "--selected-choices", *choices, "--notes", note[:2084])


def risk_counts(milestone=None):
    for lens in LENSES:
        args = ["get-lens-review", "--workload-id", W, "--lens-alias", lens]
        if milestone:
            args += ["--milestone-number", str(milestone)]
        r = aws(*args)["LensReview"]
        print(f"  {lens:16s} {json.dumps(r.get('RiskCounts', {}), sort_keys=True)}")


def milestone(name):
    m = aws("create-milestone", "--workload-id", W, "--milestone-name", name)
    print(f"Milestone {m['MilestoneNumber']} created: {name}")
    return m["MilestoneNumber"]


phase = sys.argv[1] if len(sys.argv) > 1 else ""
if phase == "baseline":
    n = 0
    for lens in LENSES:
        for qid, q in A[lens].items():
            set_answer(lens, qid, q["b"], q["n"])
            n += 1
    print(f"Answered {n} questions (baseline).")
    num = milestone("M1 Baseline (pre-remediation)")
    print("Risk counts, Milestone", num)
    risk_counts(num)
elif phase == "post":
    n = 0
    for lens in LENSES:
        for qid, q in A[lens].items():
            if "p" in q:
                set_answer(lens, qid, q["p"], q["n"])
                n += 1
    print(f"Updated {n} questions (post-remediation).")
    num = milestone("M2 Post-remediation (P1 OAC, password policy, Access Analyzer, leftover cleanup)")
    print("Risk counts, Milestone", num)
    risk_counts(num)
    for lens in LENSES:
        r = aws("get-lens-review-report", "--workload-id", W, "--lens-alias", lens,
                "--milestone-number", str(num))
        path = f"wa-tool/lens-review-report-{lens}.pdf"
        open(path, "wb").write(base64.b64decode(r["LensReviewReport"]["Base64String"]))
        print("Saved", path)
else:
    sys.exit(__doc__)
