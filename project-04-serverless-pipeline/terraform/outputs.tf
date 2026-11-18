output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_stage.main.invoke_url
}

output "sqs_queue_url" {
  description = "SQS queue URL"
  value       = aws_sqs_queue.data_queue.url
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.data_table.name
}

output "ingest_function" {
  description = "Ingest Lambda function name"
  value       = aws_lambda_function.ingest.function_name
}

output "process_function" {
  description = "Process Lambda function name"
  value       = aws_lambda_function.process.function_name
}

output "query_function" {
  description = "Query Lambda function name"
  value       = aws_lambda_function.query.function_name
}
