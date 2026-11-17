# Project 10: Project 4's serverless pipeline rebuilt to fix the Project 8 review findings.
# HTTP API (IAM auth, throttled) -> ingest Lambda -> SQS (+DLQ) -> process Lambda -> DynamoDB (+ stats table)
# Every IAM role carries the p10-workload-boundary created by the P9 bootstrap stack.

variable "protect_data" {
  description = "DynamoDB deletion protection; set to false only for the final teardown"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  type    = number
  default = 14
}

data "aws_caller_identity" "current" {}

locals {
  name         = "p10"
  account      = data.aws_caller_identity.current.account_id
  boundary_arn = "arn:aws:iam::${local.account}:policy/p10-workload-boundary"
  functions = {
    ingest  = { timeout = 10, env = { QUEUE_URL = aws_sqs_queue.main.url } }
    process = { timeout = 30, env = { TABLE_NAME = aws_dynamodb_table.data.name, STATS_TABLE_NAME = aws_dynamodb_table.stats.name } }
    query   = { timeout = 10, env = { TABLE_NAME = aws_dynamodb_table.data.name, STATS_TABLE_NAME = aws_dynamodb_table.stats.name } }
  }
}

# ---------------- Storage ----------------
resource "aws_dynamodb_table" "data" {
  #checkov:skip=CKV_AWS_28:Point-in-time recovery is billed per GB-month; data is demo data (P8 F-49, cost decision)
  #checkov:skip=CKV_AWS_119:Encrypted with the AWS owned key; a customer-managed KMS key costs about USD 1/month (cost decision)
  name                        = "${local.name}-data"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "id"
  deletion_protection_enabled = var.protect_data # P8 F-49

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "stats" {
  #checkov:skip=CKV_AWS_28:Counters are rebuilt from the data table if lost (cost decision)
  #checkov:skip=CKV_AWS_119:Encrypted with the AWS owned key (cost decision)
  name                        = "${local.name}-stats"
  billing_mode                = "PAY_PER_REQUEST"
  hash_key                    = "source"
  deletion_protection_enabled = var.protect_data

  attribute {
    name = "source"
    type = "S"
  }
}

# ---------------- Queues ----------------
resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name}-dlq"
  message_retention_seconds = 1209600 # 14 days, longer than the source queue (P8 F-46)
  sqs_managed_sse_enabled   = true
}

resource "aws_sqs_queue" "main" {
  name                       = "${local.name}-queue"
  visibility_timeout_seconds = 180    # 6 x the process timeout (P8 F-44)
  message_retention_seconds  = 345600 # 4 days
  sqs_managed_sse_enabled    = true
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# ---------------- Lambda functions: one role each, all bounded ----------------
data "archive_file" "fn" {
  for_each    = local.functions
  type        = "zip"
  source_file = "${path.module}/../src/${each.key}/lambda_function.py"
  output_path = "${path.module}/build/${each.key}.zip"
}

resource "aws_cloudwatch_log_group" "fn" {
  #checkov:skip=CKV_AWS_158:Logs encrypted by CloudWatch by default; a customer-managed KMS key is a cost decision
  #checkov:skip=CKV_AWS_338:14-day retention is deliberate for a demo; one year of logs is not needed (P8 F-40)
  for_each          = local.functions
  name              = "/aws/lambda/${local.name}-${each.key}"
  retention_in_days = var.log_retention_days
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fn" {
  for_each             = local.functions
  name                 = "${local.name}-${each.key}-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_trust.json
  permissions_boundary = local.boundary_arn
}

# Per-function permissions (P8 F-38): each function can reach only what it uses.
data "aws_iam_policy_document" "fn" {
  for_each = local.functions

  statement {
    sid       = "OwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.fn[each.key].arn}:*"]
  }
  statement {
    sid       = "Tracing"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = each.key == "ingest" ? [1] : []
    content {
      sid       = "SendToQueue"
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.main.arn]
    }
  }
  dynamic "statement" {
    for_each = each.key == "process" ? [1] : []
    content {
      sid       = "ConsumeQueue"
      actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:ChangeMessageVisibility", "sqs:GetQueueAttributes"]
      resources = [aws_sqs_queue.main.arn]
    }
  }
  dynamic "statement" {
    for_each = each.key == "process" ? [1] : []
    content {
      sid       = "WriteRecordsAndCounters"
      actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:ConditionCheckItem"]
      resources = [aws_dynamodb_table.data.arn, aws_dynamodb_table.stats.arn]
    }
  }
  dynamic "statement" {
    for_each = each.key == "query" ? [1] : []
    content {
      sid       = "ReadRecordsAndCounters"
      actions   = ["dynamodb:GetItem", "dynamodb:Scan"]
      resources = [aws_dynamodb_table.data.arn, aws_dynamodb_table.stats.arn]
    }
  }
}

resource "aws_iam_role_policy" "fn" {
  for_each = local.functions
  name     = "least-privilege"
  role     = aws_iam_role.fn[each.key].id
  policy   = data.aws_iam_policy_document.fn[each.key].json
}

resource "aws_lambda_function" "fn" {
  #checkov:skip=CKV_AWS_116:Invoked synchronously (API) or by SQS, which has its own DLQ; a Lambda DLQ does not apply
  #checkov:skip=CKV_AWS_117:No VPC resources to reach; a VPC would need NAT or endpoints (cost decision)
  #checkov:skip=CKV_AWS_173:Environment variables hold no secrets (queue URL, table names); default encryption is used
  #checkov:skip=CKV_AWS_272:Code signing not configured; deploys only come from the gated pipeline on main
  #checkov:skip=CKV_AWS_115:Reserved concurrency impossible with the account limit of 10; capped via SQS maximum_concurrency and API throttling (P8 F-51)
  for_each         = local.functions
  function_name    = "${local.name}-${each.key}"
  role             = aws_iam_role.fn[each.key].arn
  runtime          = "python3.12"
  architectures    = ["arm64"] # Graviton (P8 F-50)
  handler          = "lambda_function.handler"
  filename         = data.archive_file.fn[each.key].output_path
  source_code_hash = data.archive_file.fn[each.key].output_base64sha256
  memory_size      = 128
  timeout          = each.value.timeout

  tracing_config { mode = "Active" } # X-Ray (P8 F-47)

  environment { variables = each.value.env }

  depends_on = [aws_cloudwatch_log_group.fn, aws_iam_role_policy.fn]
}

resource "aws_lambda_event_source_mapping" "process" {
  event_source_arn        = aws_sqs_queue.main.arn
  function_name           = aws_lambda_function.fn["process"].arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"] # P8 F-45
  scaling_config { maximum_concurrency = 2 }            # P8 F-51
}

# ---------------- HTTP API: IAM auth on every route, throttled ----------------
resource "aws_apigatewayv2_api" "main" {
  name          = "${local.name}-api"
  protocol_type = "HTTP"
  description   = "P10 serverless v2: every route requires SigV4 (AWS_IAM) authorization"
}

resource "aws_cloudwatch_log_group" "api" {
  #checkov:skip=CKV_AWS_158:Logs encrypted by CloudWatch by default; a customer-managed KMS key is a cost decision
  #checkov:skip=CKV_AWS_338:14-day retention is deliberate for a demo
  name              = "/aws/apigateway/${local.name}-api"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  default_route_settings { # P8 F-43
    throttling_rate_limit  = 5
    throttling_burst_limit = 10
  }

  access_log_settings { # P8 F-47
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId = "$context.requestId", ip = "$context.identity.sourceIp", caller = "$context.identity.caller",
      routeKey = "$context.routeKey", status = "$context.status", latencyMs = "$context.responseLatency",
      authError = "$context.authorizer.error", integrationError = "$context.integrationErrorMessage"
    })
  }
}

locals {
  routes = {
    "POST /ingest"    = "ingest"
    "GET /data"       = "query"
    "GET /data/{id}"  = "query"
    "GET /stats"      = "query"
  }
}

resource "aws_apigatewayv2_integration" "fn" {
  for_each               = toset(["ingest", "query"])
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.fn[each.key].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "r" {
  for_each           = local.routes
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = each.key
  authorization_type = "AWS_IAM" # P8 F-42
  target             = "integrations/${aws_apigatewayv2_integration.fn[each.value].id}"
}

resource "aws_lambda_permission" "api" {
  for_each      = toset(["ingest", "query"])
  statement_id  = "AllowApiGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.fn[each.key].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# ---------------- Test client role: may call the API, nothing else ----------------
data "aws_iam_policy_document" "client_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account}:user/admin"]
    }
  }
}

resource "aws_iam_role" "client" {
  name                 = "${local.name}-api-client"
  description          = "Signed (SigV4) caller for the P10 API, used for testing"
  assume_role_policy   = data.aws_iam_policy_document.client_trust.json
  permissions_boundary = local.boundary_arn
  max_session_duration = 3600
}

resource "aws_iam_role_policy" "client" {
  name = "invoke-p10-api"
  role = aws_iam_role.client.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "InvokeP10Api"
      Effect   = "Allow"
      Action   = "execute-api:Invoke"
      Resource = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
    }]
  })
}

# ---------------- Monitoring (P8 F-39) ----------------
resource "aws_sns_topic" "alarms" {
  name              = "${local.name}-alarms"
  kms_master_key_id = "alias/aws/sns" # AWS managed key, no charge
}

resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name          = "${local.name}-dlq-not-empty"
  alarm_description   = "Messages failed processing 3 times and reached the dead-letter queue"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.dlq.name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]
}

resource "aws_cloudwatch_metric_alarm" "errors" {
  for_each            = local.functions
  alarm_name          = "${local.name}-${each.key}-errors"
  alarm_description   = "Lambda ${each.key} reported errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = aws_lambda_function.fn[each.key].function_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}

# ---------------- Outputs ----------------
output "api_endpoint" { value = aws_apigatewayv2_api.main.api_endpoint }
output "client_role_arn" { value = aws_iam_role.client.arn }
output "alarm_topic_arn" { value = aws_sns_topic.alarms.arn }
output "dlq_url" { value = aws_sqs_queue.dlq.url }
