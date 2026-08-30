# -----------------------------------------------
# SQS Queue (buffers incoming data)
# -----------------------------------------------
resource "aws_sqs_queue" "data_queue" {
  name                       = "serverless-data-queue"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10

  tags = {
    Name = "serverless-data-queue"
  }
}

# -----------------------------------------------
# Dead Letter Queue (stores failed messages)
# -----------------------------------------------
resource "aws_sqs_queue" "dlq" {
  name = "serverless-data-dlq"

  tags = {
    Name = "serverless-data-dlq"
  }
}

resource "aws_sqs_queue_redrive_policy" "data_queue" {
  queue_url = aws_sqs_queue.data_queue.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# -----------------------------------------------
# DynamoDB Table (stores processed data)
# -----------------------------------------------
resource "aws_dynamodb_table" "data_table" {
  name         = "serverless-data-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "serverless-data-table"
  }
}
