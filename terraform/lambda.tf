# ──────────────────────────────────────────────
# ECR — Registry Docker pour les images Lambda
# ──────────────────────────────────────────────

resource "aws_ecr_repository" "lambda_a" {
  name                 = "${var.project_name}/lambda-a"
  image_tag_mutability = "IMMUTABLE" # Sécurité : pas d'écrasement de tag

  image_scanning_configuration {
    scan_on_push = true # Scan de vulnérabilités à chaque push
  }

  tags = { Name = "${var.project_name}-lambda-a-ecr" }
}

resource "aws_ecr_repository" "lambda_b" {
  name                 = "${var.project_name}/lambda-b"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${var.project_name}-lambda-b-ecr" }
}

# Politique de cycle de vie — garde uniquement les 10 dernières images
resource "aws_ecr_lifecycle_policy" "lambda_a" {
  repository = aws_ecr_repository.lambda_a.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Garder les 10 dernières images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

resource "aws_ecr_lifecycle_policy" "lambda_b" {
  repository = aws_ecr_repository.lambda_b.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Garder les 10 dernières images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# ──────────────────────────────────────────────
# Lambda A — Reçoit API Gateway, publie sur EventBridge
# ──────────────────────────────────────────────

resource "aws_lambda_function" "lambda_a" {
  function_name = "${var.project_name}-lambda-a-${var.environment}"
  role          = aws_iam_role.lambda_a.arn
  package_type  = "Image"

  # L'image est poussée par le pipeline CI/CD
  # Le tag "latest" est résolu dynamiquement
  image_uri = "${aws_ecr_repository.lambda_a.repository_url}:latest"

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_sec

  environment {
    variables = {
      ENVIRONMENT      = var.environment
      EVENT_BUS_NAME   = aws_cloudwatch_event_bus.main.name
      EVENT_SOURCE     = "${var.project_name}.lambda-a"
      EVENT_DETAIL_TYPE = "ProcessingComplete"
      LOG_LEVEL        = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_a]
}

# Autorisation API Gateway → Lambda A
resource "aws_lambda_permission" "apigw_lambda_a" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_a.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# ──────────────────────────────────────────────
# Lambda B — Consomme SQS, publie sur SNS
# ──────────────────────────────────────────────

resource "aws_lambda_function" "lambda_b" {
  function_name = "${var.project_name}-lambda-b-${var.environment}"
  role          = aws_iam_role.lambda_b.arn
  package_type  = "Image"

  image_uri = "${aws_ecr_repository.lambda_b.repository_url}:latest"

  memory_size = var.lambda_memory_mb
  timeout     = var.lambda_timeout_sec

  environment {
    variables = {
      ENVIRONMENT = var.environment
      SNS_ARN     = aws_sns_topic.alerts.arn
      LOG_LEVEL   = "INFO"
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda_b]
}

# Trigger Lambda B depuis SQS
resource "aws_lambda_event_source_mapping" "sqs_to_lambda_b" {
  event_source_arn = aws_sqs_queue.main.arn
  function_name    = aws_lambda_function.lambda_b.arn
  batch_size       = 10 # Traite jusqu'à 10 messages à la fois

  # En cas d'erreur, renvoie vers DLQ (géré par SQS redrive_policy)
  function_response_types = ["ReportBatchItemFailures"]
}
