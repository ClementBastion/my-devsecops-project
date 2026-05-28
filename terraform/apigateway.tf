# ──────────────────────────────────────────────
# API Gateway v2 (HTTP API) — plus léger et
# moins cher que REST API pour des Lambdas
# ──────────────────────────────────────────────

resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  description   = "API HTTP pour ${var.project_name} - ${var.environment}"

  cors_configuration {
    allow_origins = ["*"] # À restreindre en prod
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
}

# Stage de déploiement avec logs activés
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = var.environment
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }
}

# Intégration API Gateway → Lambda A
resource "aws_apigatewayv2_integration" "lambda_a" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.lambda_a.invoke_arn
  payload_format_version = "2.0"
}

# Route POST /process → Lambda A
resource "aws_apigatewayv2_route" "process" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /process"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_a.id}"
}

# Route GET /health → Lambda A (healthcheck)
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_a.id}"
}
