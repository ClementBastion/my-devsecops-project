# ──────────────────────────────────────────────
# CloudWatch — Logs + Alarmes
# Observabilité complète sur tous les composants
# ──────────────────────────────────────────────

# Log groups — créés avant les Lambdas pour éviter les dépendances circulaires
resource "aws_cloudwatch_log_group" "lambda_a" {
  name              = "/aws/lambda/${var.project_name}-lambda-a-${var.environment}"
  retention_in_days = var.cloudwatch_retention_days
}

resource "aws_cloudwatch_log_group" "lambda_b" {
  name              = "/aws/lambda/${var.project_name}-lambda-b-${var.environment}"
  retention_in_days = var.cloudwatch_retention_days
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}"
  retention_in_days = var.cloudwatch_retention_days
}

# ── Alarmes Lambda A ──

resource "aws_cloudwatch_metric_alarm" "lambda_a_errors" {
  alarm_name          = "${var.project_name}-lambda-a-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda A a rencontré des erreurs"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.lambda_a.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_a_duration" {
  alarm_name          = "${var.project_name}-lambda-a-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Average"
  threshold           = var.lambda_timeout_sec * 800 # 80% du timeout en ms
  alarm_description   = "Lambda A approche de son timeout"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.lambda_a.function_name
  }
}

# ── Alarmes Lambda B ──

resource "aws_cloudwatch_metric_alarm" "lambda_b_errors" {
  alarm_name          = "${var.project_name}-lambda-b-errors-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda B a rencontré des erreurs"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.lambda_b.function_name
  }
}

# ── Dashboard CloudWatch ──

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "Lambda A — Invocations & Erreurs"
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.lambda_a.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.lambda_a.function_name]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "Lambda B — Invocations & Erreurs"
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.lambda_b.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.lambda_b.function_name]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "SQS — Messages en queue"
          region  = var.aws_region
          period  = 60
          stat    = "Average"
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.main.name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", aws_sqs_queue.dlq.name]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "API Gateway — Requêtes & Latence"
          region  = var.aws_region
          period  = 60
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.http.id],
            ["AWS/ApiGateway", "Latency", "ApiId", aws_apigatewayv2_api.http.id]
          ]
        }
      }
    ]
  })
}
