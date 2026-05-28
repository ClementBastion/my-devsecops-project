# ──────────────────────────────────────────────
# IAM — principe du moindre privilège
# Chaque Lambda a son propre rôle, limité
# strictement à ce dont elle a besoin
# ──────────────────────────────────────────────

# ── Rôle Lambda A (API Gateway → EventBridge) ──

resource "aws_iam_role" "lambda_a" {
  name = "${var.project_name}-lambda-a-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_a_policy" {
  name = "${var.project_name}-lambda-a-policy"
  role = aws_iam_role.lambda_a.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Écriture des logs CloudWatch uniquement
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-lambda-a-${var.environment}:*"
      },
      {
        # Publication sur EventBridge uniquement sur notre bus
        Sid    = "AllowEventBridgePut"
        Effect = "Allow"
        Action = "events:PutEvents"
        Resource = aws_cloudwatch_event_bus.main.arn
      },
      {
        # Lecture image ECR (pull au démarrage)
        Sid    = "AllowECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# ── Rôle Lambda B (SQS → SNS) ──

resource "aws_iam_role" "lambda_b" {
  name = "${var.project_name}-lambda-b-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_b_policy" {
  name = "${var.project_name}-lambda-b-policy"
  role = aws_iam_role.lambda_b.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-lambda-b-${var.environment}:*"
      },
      {
        # Consommation SQS — uniquement notre queue
        Sid    = "AllowSQSConsume"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main.arn
      },
      {
        # Publication SNS — uniquement notre topic
        Sid    = "AllowSNSPublish"
        Effect = "Allow"
        Action = "sns:Publish"
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Sid    = "AllowECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}
