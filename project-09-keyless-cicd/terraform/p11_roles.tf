# Project 11 CI identity: a deploy-only role. It cannot create or change infrastructure.
# It may run exactly one SSM document (p11-deploy, whose only parameter is an image digest) on instances
# tagged for P11. The instance verifies the image signature itself before running anything.
# Replaces Project 3's SSH deploy (P8 finding F-29). Trust: this repository's main branch only.

locals {
  p11_tag = "p11-secure-supply-chain"
}

data "aws_iam_policy_document" "p11_deploy" {
  statement {
    sid       = "RunOnlyTheDeployDocument"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:${local.region}:${local.account}:document/p11-deploy"]
  }
  statement {
    sid       = "OnlyOnP11Instances"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:${local.region}:${local.account}:instance/*"]
    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Project"
      values   = [local.p11_tag]
    }
  }
  statement {
    sid = "ReadResults" # these read APIs have no resource-level permissions
    actions = [
      "ssm:GetCommandInvocation",
      "ssm:ListCommandInvocations",
      "ec2:DescribeInstances",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "p11_deploy" {
  name                 = "gha-p11-deploy"
  description          = "GitHub Actions (main branch): run the p11-deploy SSM document on P11 instances only"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "p11_deploy" {
  name   = "p11-deploy-only"
  role   = aws_iam_role.p11_deploy.id
  policy = data.aws_iam_policy_document.p11_deploy.json
}

output "p11_deploy_role_arn" {
  value = aws_iam_role.p11_deploy.arn
}
