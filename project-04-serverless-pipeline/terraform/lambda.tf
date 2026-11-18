# -----------------------------------------------
# IAM Role for all Lambda functions
# -----------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "serverless-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "serverless-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.data_queue.arn,
          aws_sqs_queue.dlq.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = aws_dynamodb_table.data_table.arn
      }
    ]
  })
}

# -----------------------------------------------
# Package Lambda code as zip files
# -----------------------------------------------
data "archive_file" "ingest" {
  type        = "zip"
  source_file = "${path.module}/../lambda/ingest/lambda_function.py"
  output_path = "${path.module}/../lambda/ingest/lambda.zip"
}

data "archive_file" "process" {
  type        = "zip"
  source_file = "${path.module}/../lambda/process/lambda_function.py"
  output_path = "${path.module}/../lambda/process/lambda.zip"
}

data "archive_file" "query" {
  type        = "zip"
  source_file = "${path.module}/../lambda/query/lambda_function.py"
  output_path = "${path.module}/../lambda/query/lambda.zip"
}

# -----------------------------------------------
# Ingest Lambda (receives data from API Gateway)
# -----------------------------------------------
resource "aws_lambda_function" "ingest" {
  function_name    = "serverless-ingest"
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.data_queue.url
    }
  }
}

# -----------------------------------------------
# Process Lambda (triggered by SQS messages)
# -----------------------------------------------
resource "aws_lambda_function" "process" {
  function_name    = "serverless-process"
  filename         = data.archive_file.process.output_path
  source_code_hash = data.archive_file.process.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 60

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.data_table.name
    }
  }
}

# Connect SQS to the Process Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.data_queue.arn
  function_name    = aws_lambda_function.process.arn
  batch_size       = 10
  enabled          = true
}

# -----------------------------------------------
# Query Lambda (reads data from DynamoDB)
# -----------------------------------------------
resource "aws_lambda_function" "query" {
  function_name    = "serverless-query"
  filename         = data.archive_file.query.output_path
  source_code_hash = data.archive_file.query.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.12"
  timeout          = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.data_table.name
    }
  }
}
