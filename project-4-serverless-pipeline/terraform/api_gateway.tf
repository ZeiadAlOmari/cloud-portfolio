# -----------------------------------------------
# API Gateway (HTTP API — cheaper than REST API)
# -----------------------------------------------
resource "aws_apigatewayv2_api" "main" {
  name          = "serverless-data-api"
  protocol_type = "HTTP"
}

# -----------------------------------------------
# Stage
# -----------------------------------------------
resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

# -----------------------------------------------
# Ingest Integration (POST /ingest)
# -----------------------------------------------
resource "aws_apigatewayv2_integration" "ingest" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingest.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "ingest" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /ingest"
  target    = "integrations/${aws_apigatewayv2_integration.ingest.id}"
}

resource "aws_lambda_permission" "ingest" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# -----------------------------------------------
# Query Integration (GET /data)
# -----------------------------------------------
resource "aws_apigatewayv2_integration" "query_data" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.query.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "query_data" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /data"
  target    = "integrations/${aws_apigatewayv2_integration.query_data.id}"
}

resource "aws_apigatewayv2_route" "query_data_id" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /data/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.query_data.id}"
}

# -----------------------------------------------
# Stats Integration (GET /stats)
# -----------------------------------------------
resource "aws_apigatewayv2_integration" "query_stats" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.query.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "query_stats" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /stats"
  target    = "integrations/${aws_apigatewayv2_integration.query_stats.id}"
}

resource "aws_lambda_permission" "query" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
