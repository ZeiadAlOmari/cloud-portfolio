# Project 10 CI identity: permissions boundary + plan/apply roles for the serverless v2 workload.
# Lives in the P9 bootstrap stack so the pipeline can never edit its own permissions or the boundary.

locals {
  p10_prefix   = "p10-"
  p10_state    = "p10/terraform.tfstate"
  region       = "us-east-1"
  arn_lambda   = "arn:aws:lambda:${local.region}:${local.account}"
  arn_sqs      = "arn:aws:sqs:${local.region}:${local.account}"
  arn_ddb      = "arn:aws:dynamodb:${local.region}:${local.account}"
  arn_logs     = "arn:aws:logs:${local.region}:${local.account}"
  arn_cw       = "arn:aws:cloudwatch:${local.region}:${local.account}"
  arn_sns      = "arn:aws:sns:${local.region}:${local.account}"
  arn_iam_p10  = "arn:aws:iam::${local.account}:role/${local.p10_prefix}*"
  boundary_arn = "arn:aws:iam::${local.account}:policy/p10-workload-boundary"
}

# ---------------- Permissions boundary for every role the pipeline creates ----------------
# Whatever policy the pipeline attaches to a p10-* role, the role can never exceed this.
data "aws_iam_policy_document" "p10_boundary" {
  statement {
    sid       = "OwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${local.arn_logs}:log-group:/aws/lambda/${local.p10_prefix}*:*"]
  }
  statement {
    sid       = "OwnQueues"
    actions   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes"]
    resources = ["${local.arn_sqs}:${local.p10_prefix}*"]
  }
  statement {
    sid       = "OwnTables"
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem", "dynamodb:Scan", "dynamodb:ConditionCheckItem"]
    resources = ["${local.arn_ddb}:table/${local.p10_prefix}*"]
  }
  statement {
    sid       = "Tracing" # X-Ray write APIs do not support resource-level scoping
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
  statement {
    sid       = "InvokeApi" # for the test client role
    actions   = ["execute-api:Invoke"]
    resources = ["arn:aws:execute-api:${local.region}:${local.account}:*"]
  }
}

resource "aws_iam_policy" "p10_boundary" {
  name        = "p10-workload-boundary"
  description = "Maximum permissions for any role the P10 pipeline creates"
  policy      = data.aws_iam_policy_document.p10_boundary.json
}

# ---------------- Trust: same GitHub subjects as the P1 roles ----------------
data "aws_iam_policy_document" "p10_trust_plan" {
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

data "aws_iam_policy_document" "p10_trust_apply" {
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

# ---------------- Read access (plan role, and shared by apply) ----------------
data "aws_iam_policy_document" "p10_read" {
  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["p10/*"]
    }
  }
  statement {
    sid       = "StateRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.p10_state}"]
  }
  statement {
    sid       = "StateLock"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.p10_state}.tflock"]
  }
  statement {
    sid = "ReadOwnResources"
    actions = [
      "lambda:GetFunction", "lambda:GetFunctionConfiguration", "lambda:GetFunctionCodeSigningConfig", "lambda:ListVersionsByFunction",
      "lambda:GetPolicy", "lambda:ListTags", "lambda:GetFunctionConcurrency",
      "sqs:GetQueueAttributes", "sqs:GetQueueUrl", "sqs:ListQueueTags",
      "dynamodb:DescribeTable", "dynamodb:DescribeContinuousBackups", "dynamodb:DescribeTimeToLive", "dynamodb:ListTagsOfResource",
      "iam:GetRole", "iam:GetRolePolicy", "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
      "sns:GetTopicAttributes", "sns:ListTagsForResource",
      "cloudwatch:ListTagsForResource", "cloudwatch:DescribeAlarms",
    ]
    resources = [
      "${local.arn_lambda}:function:${local.p10_prefix}*",
      "${local.arn_sqs}:${local.p10_prefix}*",
      "${local.arn_ddb}:table/${local.p10_prefix}*",
      local.arn_iam_p10,
      "${local.arn_sns}:${local.p10_prefix}*",
      "${local.arn_cw}:alarm:${local.p10_prefix}*",
    ]
  }
  statement {
    sid       = "ReadEventSourceMappings"
    actions   = ["lambda:GetEventSourceMapping", "lambda:ListTags"]
    resources = ["${local.arn_lambda}:event-source-mapping:*"]
  }
  statement {
    sid = "ReadNoResourceScope" # describe/list calls without resource-level scoping
    actions = [
      "lambda:ListEventSourceMappings", "logs:DescribeLogGroups",
    ]
    resources = ["*"]
  }
  statement {
    sid     = "ReadOwnLogGroupTags"
    actions = ["logs:ListTagsForResource", "logs:ListTagsLogGroup"]
    resources = [
      "${local.arn_logs}:log-group:/aws/lambda/${local.p10_prefix}*",
      "${local.arn_logs}:log-group:/aws/apigateway/${local.p10_prefix}*",
    ]
  }
  statement {
    sid       = "ReadHttpApis" # API IDs are generated, so scope is the HTTP API collection
    actions   = ["apigateway:GET"]
    resources = ["arn:aws:apigateway:${local.region}::/apis", "arn:aws:apigateway:${local.region}::/apis/*", "arn:aws:apigateway:${local.region}::/tags/*"]
  }
}

# ---------------- Write access (apply role only) ----------------
data "aws_iam_policy_document" "p10_write" {
  #checkov:skip=CKV_AWS_356:API Gateway requires logs:CreateLogGroup on "*" for the caller that enables HTTP API access logging (AWS docs: http-api-logging); without it CreateStage is denied
  #checkov:skip=CKV_AWS_111:Same AWS requirement - logs:CreateLogGroup with Resource "*" for HTTP API access logging; all other writes are scoped to p10-* resources
  statement {
    sid       = "StateWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.p10_state}"]
  }
  statement {
    sid     = "CreateRolesOnlyWithBoundary"
    actions = ["iam:CreateRole", "iam:PutRolePermissionsBoundary"]
    resources = [local.arn_iam_p10]
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_arn]
    }
  }
  statement {
    sid = "ManageOwnRoles"
    actions = [
      "iam:DeleteRole", "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:TagRole", "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy", "iam:ListInstanceProfilesForRole",
    ]
    resources = [local.arn_iam_p10]
  }
  statement {
    sid       = "PassOwnRolesToLambdaOnly"
    actions   = ["iam:PassRole"]
    resources = [local.arn_iam_p10]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["lambda.amazonaws.com"]
    }
  }
  statement {
    sid = "ManageOwnWorkload"
    actions = [
      "lambda:CreateFunction", "lambda:DeleteFunction", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
      "lambda:AddPermission", "lambda:RemovePermission", "lambda:TagResource", "lambda:UntagResource",
      "lambda:PutFunctionConcurrency", "lambda:DeleteFunctionConcurrency",
      "sqs:CreateQueue", "sqs:DeleteQueue", "sqs:SetQueueAttributes", "sqs:TagQueue", "sqs:UntagQueue",
      "dynamodb:CreateTable", "dynamodb:DeleteTable", "dynamodb:UpdateTable", "dynamodb:UpdateContinuousBackups",
      "dynamodb:UpdateTimeToLive", "dynamodb:TagResource", "dynamodb:UntagResource",
      "sns:CreateTopic", "sns:DeleteTopic", "sns:SetTopicAttributes", "sns:TagResource", "sns:UntagResource",
      "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:TagResource", "cloudwatch:UntagResource",
    ]
    resources = [
      "${local.arn_lambda}:function:${local.p10_prefix}*",
      "${local.arn_sqs}:${local.p10_prefix}*",
      "${local.arn_ddb}:table/${local.p10_prefix}*",
      "${local.arn_sns}:${local.p10_prefix}*",
      "${local.arn_cw}:alarm:${local.p10_prefix}*",
    ]
  }
  statement {
    sid       = "CreateEventSourceMappingForOwnFunctions"
    actions   = ["lambda:CreateEventSourceMapping"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "lambda:FunctionArn"
      values   = ["${local.arn_lambda}:function:${local.p10_prefix}*"]
    }
  }
  statement {
    sid       = "ManageEventSourceMappings"
    actions   = ["lambda:UpdateEventSourceMapping", "lambda:DeleteEventSourceMapping"]
    resources = ["${local.arn_lambda}:event-source-mapping:*"]
    condition {
      test     = "StringLike"
      variable = "lambda:FunctionArn"
      values   = ["${local.arn_lambda}:function:${local.p10_prefix}*"]
    }
  }
  statement {
    sid       = "TagEventSourceMappings" # tagging calls carry no function ARN to condition on
    actions   = ["lambda:TagResource", "lambda:UntagResource"]
    resources = ["${local.arn_lambda}:event-source-mapping:*"]
  }
  statement {
    sid = "ManageOwnLogGroups"
    actions = [
      "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
      "logs:TagResource", "logs:UntagResource", "logs:TagLogGroup",
    ]
    resources = [
      "${local.arn_logs}:log-group:/aws/lambda/${local.p10_prefix}*",
      "${local.arn_logs}:log-group:/aws/lambda/${local.p10_prefix}*:*",
      "${local.arn_logs}:log-group:/aws/apigateway/${local.p10_prefix}*",
      "${local.arn_logs}:log-group:/aws/apigateway/${local.p10_prefix}*:*",
    ]
  }
  statement {
    sid = "ApiAccessLogDelivery" # exact permissions AWS requires to enable HTTP API access logging (checked with Resource "*")
    actions = [
      "logs:CreateLogDelivery", "logs:GetLogDelivery", "logs:UpdateLogDelivery", "logs:DeleteLogDelivery",
      "logs:ListLogDeliveries", "logs:PutResourcePolicy", "logs:DescribeResourcePolicies", "logs:CreateLogGroup",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "ApiAccessLogRead" # also required by API Gateway when enabling access logging
    actions   = ["logs:DescribeLogGroups", "logs:DescribeLogStreams", "logs:GetLogEvents", "logs:FilterLogEvents"]
    resources = ["${local.arn_logs}:log-group:*"]
  }
  statement {
    sid       = "ManageHttpApis"
    actions   = ["apigateway:POST", "apigateway:PATCH", "apigateway:PUT", "apigateway:DELETE"]
    resources = ["arn:aws:apigateway:${local.region}::/apis", "arn:aws:apigateway:${local.region}::/apis/*", "arn:aws:apigateway:${local.region}::/tags/*"]
  }
  statement {
    sid    = "GuardrailNeverTouchCiOrBoundary"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary", "iam:CreatePolicyVersion", "iam:DeletePolicy", "iam:SetDefaultPolicyVersion",
    ]
    resources = ["*"]
  }
  statement {
    sid       = "GuardrailNoStateDeletion"
    effect    = "Deny"
    actions   = ["s3:DeleteBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
}

resource "aws_iam_role" "p10_plan" {
  name                 = "gha-p10-plan"
  description          = "GitHub Actions (pull requests): terraform plan for P10, read-only"
  assume_role_policy   = data.aws_iam_policy_document.p10_trust_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "p10_plan_read" {
  name   = "read"
  role   = aws_iam_role.p10_plan.id
  policy = data.aws_iam_policy_document.p10_read.json
}

resource "aws_iam_role" "p10_apply" {
  name                 = "gha-p10-apply"
  description          = "GitHub Actions (main branch): terraform apply for P10 only; created roles must carry the p10 boundary"
  assume_role_policy   = data.aws_iam_policy_document.p10_trust_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "p10_apply_read" {
  name   = "read"
  role   = aws_iam_role.p10_apply.id
  policy = data.aws_iam_policy_document.p10_read.json
}

resource "aws_iam_role_policy" "p10_apply_write" {
  name   = "write"
  role   = aws_iam_role.p10_apply.id
  policy = data.aws_iam_policy_document.p10_write.json
}

output "p10_plan_role_arn" { value = aws_iam_role.p10_plan.arn }
output "p10_apply_role_arn" { value = aws_iam_role.p10_apply.arn }
output "p10_boundary_arn" { value = aws_iam_policy.p10_boundary.arn }
