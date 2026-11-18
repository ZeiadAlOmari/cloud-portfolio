data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.name
  trail_name  = "portfolio-trail"
  bucket_name = "cloud-portfolio-trail-${local.account_id}"
  role_name   = "portfolio-deployer"
  policy_name = "portfolio-deployer-policy"

  # Constructed (not referenced) so the deployer policy can protect itself without a dependency cycle
  role_arn   = "arn:aws:iam::${local.account_id}:role/${local.role_name}"
  policy_arn = "arn:aws:iam::${local.account_id}:policy/${local.policy_name}"
  trail_arn  = "arn:aws:cloudtrail:${local.region}:${local.account_id}:trail/${local.trail_name}"
}

# ---------------------------------------------------------------
# 1. Account password policy
# ---------------------------------------------------------------
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 5
}

# ---------------------------------------------------------------
# 2. Least-privilege deployer role (MFA required to assume)
# ---------------------------------------------------------------
data "aws_iam_policy_document" "trust" {
  statement {
    sid     = "AssumeOnlyWithMfa"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:user/${var.trusted_user}"]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

data "aws_iam_policy_document" "deployer" {
  # Services the portfolio projects actually use
  statement {
    sid    = "PortfolioServices"
    effect = "Allow"
    actions = [
      "ec2:*",
      "elasticloadbalancing:*",
      "autoscaling:*",
      "s3:*",
      "cloudfront:*",
      "acm:*",
      "route53:*",
      "rds:*",
      "dynamodb:*",
      "lambda:*",
      "apigateway:*",
      "sqs:*",
      "sns:*",
      "events:*",
      "logs:*",
      "cloudwatch:*",
      "cloudformation:*",
      "ssm:*",
      "codebuild:*",
      "codepipeline:*",
      "codestar-connections:*",
      "ecr:*",
      "kms:Describe*",
      "kms:List*",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
    ]
    resources = ["*"]
  }

  # IAM: roles/policies/instance profiles only (needed for Lambda, EC2, CI/CD roles)
  statement {
    sid    = "IamRolesAndPolicies"
    effect = "Allow"
    actions = [
      "iam:Get*",
      "iam:List*",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PassRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
  }

  # Guardrail: no human-identity or credential management
  statement {
    sid    = "DenyUserAndCredentialManagement"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:UpdateUser",
      "iam:CreateAccessKey",
      "iam:UpdateAccessKey",
      "iam:DeleteAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:DeleteLoginProfile",
      "iam:AttachUserPolicy",
      "iam:PutUserPolicy",
      "iam:CreateGroup",
      "iam:AddUserToGroup",
      "iam:AttachGroupPolicy",
      "iam:PutGroupPolicy",
      "iam:DeactivateMFADevice",
      "iam:DeleteVirtualMFADevice",
      "iam:UpdateAccountPasswordPolicy",
      "iam:DeleteAccountPasswordPolicy",
    ]
    resources = ["*"]
  }

  # Guardrail: cannot hand out admin-level managed policies
  statement {
    sid       = "DenyAttachingAdminPolicies"
    effect    = "Deny"
    actions   = ["iam:AttachRolePolicy"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values = [
        "arn:aws:iam::aws:policy/AdministratorAccess",
        "arn:aws:iam::aws:policy/IAMFullAccess",
      ]
    }
  }

  # Guardrail: cannot edit itself (blocks self-escalation)
  statement {
    sid    = "ProtectDeployerRoleAndPolicy"
    effect = "Deny"
    actions = [
      "iam:UpdateAssumeRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DeleteRole",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeletePolicy",
    ]
    resources = [local.role_arn, local.policy_arn]
  }

  # Guardrail: audit trail and its bucket are tamper-proof from this role
  statement {
    sid    = "ProtectAuditTrail"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
      "access-analyzer:DeleteAnalyzer",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ProtectTrailBucket"
    effect = "Deny"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketPublicAccessBlock",
    ]
    resources = [
      "arn:aws:s3:::${local.bucket_name}",
      "arn:aws:s3:::${local.bucket_name}/*",
    ]
  }

  # Guardrail: regional API calls only in approved regions (global services exempt)
  statement {
    sid    = "DenyOutsideAllowedRegions"
    effect = "Deny"
    not_actions = [
      "iam:*",
      "sts:*",
      "cloudfront:*",
      "route53:*",
      "route53domains:*",
      "budgets:*",
      "support:*",
      "organizations:*",
      "account:*",
      "health:*",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.allowed_regions
    }
  }
}

resource "aws_iam_policy" "deployer" {
  name        = local.policy_name
  description = "Least-privilege permissions for portfolio deployments"
  policy      = data.aws_iam_policy_document.deployer.json
}

resource "aws_iam_role" "deployer" {
  name                 = local.role_name
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "deployer" {
  role       = aws_iam_role.deployer.name
  policy_arn = aws_iam_policy.deployer.arn
}

# ---------------------------------------------------------------
# 3. CloudTrail -> locked-down S3 bucket
# ---------------------------------------------------------------
resource "aws_s3_bucket" "trail" {
  bucket        = local.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  bucket = aws_s3_bucket.trail.id

  rule {
    id     = "expire-logs-after-30-days"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

data "aws_iam_policy_document" "trail_bucket" {
  statement {
    sid       = "CloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "CloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail.arn}/AWSLogs/${local.account_id}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id
  policy = data.aws_iam_policy_document.trail_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.trail]
}

resource "aws_cloudtrail" "main" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.trail.id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  depends_on = [aws_s3_bucket_policy.trail]
}

# ---------------------------------------------------------------
# 4. IAM Access Analyzer (external-access findings, free tier)
# ---------------------------------------------------------------
resource "aws_accessanalyzer_analyzer" "main" {
  analyzer_name = "portfolio-analyzer"
  type          = "ACCOUNT"
}
