# Project 9 bootstrap: Terraform state bucket, GitHub OIDC provider, and two CI roles.
# This stack uses LOCAL state on purpose (it creates the remote-state bucket itself).

terraform {
  required_version = ">= 1.11"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

provider "aws" {
  region = "us-east-1"
  default_tags { tags = { Project = "p9-keyless-cicd", ManagedBy = "terraform" } }
}

variable "github_repo" {
  description = "owner/repo allowed to assume the CI roles"
  type        = string
  default     = "ZeiadAlOmari/cloud-portfolio"
}

variable "site_bucket" {
  description = "P1 site bucket the apply role may manage"
  type        = string
  default     = "portfolio-site-00c164mo"
}

variable "distribution_id" {
  description = "P1 CloudFront distribution the apply role may manage"
  type        = string
  default     = "E23VJY9UXT8NRG"
}

data "aws_caller_identity" "current" {}

locals {
  account    = data.aws_caller_identity.current.account_id
  state_key  = "p1/terraform.tfstate"
  site_arn   = "arn:aws:s3:::${var.site_bucket}"
  dist_arn   = "arn:aws:cloudfront::${local.account}:distribution/${var.distribution_id}"
  oac_arns   = "arn:aws:cloudfront::${local.account}:origin-access-control/*"
  rhp_arns   = "arn:aws:cloudfront::${local.account}:response-headers-policy/*"
  oidc_host  = "token.actions.githubusercontent.com"
}

# ---------------- Remote state bucket ----------------
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18:Access logs need a second bucket and storage; CloudTrail Event History covers management calls (cost decision)
  #checkov:skip=CKV_AWS_144:Cross-region replication doubles storage and adds transfer cost; state is reproducible (cost decision)
  #checkov:skip=CKV_AWS_145:SSE-S3 used; a customer-managed KMS key costs about USD 1/month (cost decision)
  #checkov:skip=CKV2_AWS_62:No consumer for event notifications on a state bucket (not applicable)
  bucket = "cloud-portfolio-tfstate-${random_string.suffix.result}"
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" } # recover from a bad state write
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

# P8 lesson (F-52): versioning without a lifecycle rule keeps "deleted" data forever.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
  depends_on = [aws_s3_bucket_versioning.state]
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ---------------- GitHub OIDC provider ----------------
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
  # AWS validates GitHub's certificate via its trusted CA library; thumbprints kept for provider compatibility.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${var.github_sub_prefix}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${var.github_sub_prefix}:ref:refs/heads/main"]
    }
  }
}

# ---------------- Permissions ----------------
# Read P1's resources and state; write only the lock file. Shared by both roles.
data "aws_iam_policy_document" "read" {
  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["p1/*"]
    }
  }
  statement {
    sid       = "StateRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_key}"]
  }
  statement {
    sid       = "StateLock"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_key}.tflock"]
  }
  statement {
    sid       = "SiteRead"
    actions   = ["s3:Get*", "s3:List*"]
    resources = [local.site_arn, "${local.site_arn}/*"]
  }
  statement {
    sid       = "CloudFrontRead"
    actions   = ["cloudfront:Get*", "cloudfront:ListTagsForResource"]
    resources = [local.dist_arn, local.oac_arns, local.rhp_arns]
  }
  statement {
    sid       = "CloudFrontList" # List calls have no resource-level scoping
    actions   = ["cloudfront:ListDistributions", "cloudfront:ListOriginAccessControls", "cloudfront:ListResponseHeadersPolicies"]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "write" {
  statement {
    sid       = "StateWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_key}"]
  }
  statement {
    sid = "SiteWrite"
    actions = [
      "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketVersioning", "s3:PutLifecycleConfiguration", "s3:PutEncryptionConfiguration",
      "s3:PutBucketTagging", "s3:DeleteBucketWebsite", "s3:PutObject", "s3:DeleteObject", "s3:PutObjectTagging",
    ]
    resources = [local.site_arn, "${local.site_arn}/*"]
  }
  statement {
    sid       = "DistributionWrite"
    actions   = ["cloudfront:UpdateDistribution", "cloudfront:CreateInvalidation", "cloudfront:TagResource"]
    resources = [local.dist_arn]
  }
  statement {
    sid = "OriginAccessControl" # create/update OAC and response-headers policies
    actions = [
      "cloudfront:CreateOriginAccessControl", "cloudfront:UpdateOriginAccessControl", "cloudfront:DeleteOriginAccessControl",
      "cloudfront:CreateResponseHeadersPolicy", "cloudfront:UpdateResponseHeadersPolicy", "cloudfront:DeleteResponseHeadersPolicy",
    ]
    resources = [local.oac_arns, local.rhp_arns]
  }
  statement {
    sid       = "GuardrailNoDestroy" # CI may change the site but never delete it or the state
    effect    = "Deny"
    actions   = ["s3:DeleteBucket", "cloudfront:DeleteDistribution"]
    resources = [local.site_arn, aws_s3_bucket.state.arn, local.dist_arn]
  }
}

resource "aws_iam_role" "plan" {
  name                 = "gha-p1-plan"
  description          = "GitHub Actions (pull requests): terraform plan for P1, read-only"
  assume_role_policy   = data.aws_iam_policy_document.trust_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "plan_read" {
  name   = "read"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.read.json
}

resource "aws_iam_role" "apply" {
  name                 = "gha-p1-apply"
  description          = "GitHub Actions (main branch): terraform apply for P1 only"
  assume_role_policy   = data.aws_iam_policy_document.trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "apply_read" {
  name   = "read"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.read.json
}

resource "aws_iam_role_policy" "apply_write" {
  name   = "write"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.write.json
}

# ---------------- Outputs ----------------
output "state_bucket" { value = aws_s3_bucket.state.id }
output "plan_role_arn" { value = aws_iam_role.plan.arn }
output "apply_role_arn" { value = aws_iam_role.apply.arn }

# GitHub OIDC subject prefix with immutable owner and repository IDs (format seen in CloudTrail).
variable "github_sub_prefix" {
  type    = string
  default = "repo:ZeiadAlOmari@318468395/cloud-portfolio@1339061930"
}
