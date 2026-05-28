# ──────────────────────────────────────────────
# IAM — Utilisateur CI/CD GitHub Actions
# Permissions strictement limitées à :
#   - Terraform state (S3 + DynamoDB)
#   - ECR push/pull
#   - Lambda deploy
#   - Gestion des ressources du projet (infra TF)
# ──────────────────────────────────────────────

resource "aws_iam_user" "cicd" {
  name = "${var.project_name}-cicd"
  tags = { Name = "${var.project_name}-cicd" }
}

resource "aws_iam_access_key" "cicd" {
  user = aws_iam_user.cicd.name
}

resource "aws_iam_user_policy" "cicd" {
  name = "${var.project_name}-cicd-policy"
  user = aws_iam_user.cicd.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ── Terraform state ──────────────────────────────────────────────
      {
        Sid    = "TerraformStateS3"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.project_name}-terraform-state",
          "arn:aws:s3:::${var.project_name}-terraform-state/*"
        ]
      },
      {
        Sid      = "TerraformLockDynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-terraform-locks"
      },

      # ── ECR ──────────────────────────────────────────────────────────
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRRepositories"
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository", "ecr:DeleteRepository", "ecr:DescribeRepositories",
          "ecr:PutLifecyclePolicy", "ecr:GetLifecyclePolicy", "ecr:DeleteLifecyclePolicy",
          "ecr:PutImageTagMutability", "ecr:PutImageScanningConfiguration",
          "ecr:GetRepositoryPolicy", "ecr:SetRepositoryPolicy", "ecr:DeleteRepositoryPolicy",
          "ecr:ListTagsForResource", "ecr:TagResource", "ecr:UntagResource",
          "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
          "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer", "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:${var.aws_region}:*:repository/${var.project_name}/*"
      },

      # ── Lambda ───────────────────────────────────────────────────────
      {
        Sid    = "LambdaManagement"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction",
          "lambda:GetFunction", "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission", "lambda:RemovePermission",
          "lambda:CreateEventSourceMapping", "lambda:UpdateEventSourceMapping",
          "lambda:DeleteEventSourceMapping", "lambda:GetEventSourceMapping",
          "lambda:TagResource", "lambda:UntagResource", "lambda:ListTags"
        ]
        Resource = "arn:aws:lambda:${var.aws_region}:*:function:${var.project_name}-*"
      },
      {
        Sid      = "LambdaEventSourceList"
        Effect   = "Allow"
        Action   = "lambda:ListEventSourceMappings"
        Resource = "*"
      },

      # ── API Gateway v2 ───────────────────────────────────────────────
      {
        Sid      = "APIGateway"
        Effect   = "Allow"
        Action   = "apigateway:*"
        Resource = [
          "arn:aws:apigateway:${var.aws_region}::/apis",
          "arn:aws:apigateway:${var.aws_region}::/apis/*"
        ]
      },

      # ── EventBridge ──────────────────────────────────────────────────
      {
        Sid    = "EventBridge"
        Effect = "Allow"
        Action = [
          "events:CreateEventBus", "events:DeleteEventBus", "events:DescribeEventBus",
          "events:PutRule", "events:DeleteRule", "events:DescribeRule",
          "events:PutTargets", "events:RemoveTargets", "events:ListTargetsByRule",
          "events:TagResource", "events:UntagResource"
        ]
        Resource = [
          "arn:aws:events:${var.aws_region}:*:event-bus/${var.project_name}-*",
          "arn:aws:events:${var.aws_region}:*:rule/${var.project_name}-*",
          "arn:aws:events:${var.aws_region}:*:rule/${var.project_name}-*/*"
        ]
      },

      # ── SQS ──────────────────────────────────────────────────────────
      {
        Sid    = "SQS"
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue", "sqs:DeleteQueue",
          "sqs:GetQueueAttributes", "sqs:SetQueueAttributes",
          "sqs:GetQueueUrl", "sqs:TagQueue", "sqs:UntagQueue", "sqs:ListQueueTags"
        ]
        Resource = "arn:aws:sqs:${var.aws_region}:*:${var.project_name}-*"
      },

      # ── SNS ──────────────────────────────────────────────────────────
      {
        Sid    = "SNS"
        Effect = "Allow"
        Action = [
          "sns:CreateTopic", "sns:DeleteTopic",
          "sns:GetTopicAttributes", "sns:SetTopicAttributes",
          "sns:Subscribe", "sns:Unsubscribe", "sns:GetSubscriptionAttributes",
          "sns:ListSubscriptionsByTopic",
          "sns:TagResource", "sns:UntagResource"
        ]
        Resource = "arn:aws:sns:${var.aws_region}:*:${var.project_name}-*"
      },

      # ── IAM — rôles Lambda uniquement ────────────────────────────────
      {
        Sid    = "IAMRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateRole",
          "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
          "iam:ListRolePolicies", "iam:ListAttachedRolePolicies",
          "iam:TagRole", "iam:UntagRole"
        ]
        Resource = "arn:aws:iam::*:role/${var.project_name}-*"
      },
      {
        Sid    = "IAMPassRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "arn:aws:iam::*:role/${var.project_name}-*"
        Condition = {
          StringEquals = { "iam:PassedToService" = "lambda.amazonaws.com" }
        }
      },

      # ── CloudWatch Logs ───────────────────────────────────────────────
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:DescribeLogGroups",
          "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:ListTagsForResource", "logs:TagResource", "logs:UntagResource"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${var.project_name}-*",
          "arn:aws:logs:${var.aws_region}:*:log-group:/aws/apigateway/${var.project_name}-*"
        ]
      },

      # ── CloudWatch Alarms + Dashboard ─────────────────────────────────
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms",
          "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards", "cloudwatch:GetDashboard",
          "cloudwatch:TagResource", "cloudwatch:UntagResource"
        ]
        Resource = [
          "arn:aws:cloudwatch::*:dashboard/${var.project_name}-*",
          "arn:aws:cloudwatch:${var.aws_region}:*:alarm:${var.project_name}-*"
        ]
      }
    ]
  })
}

# ──────────────────────────────────────────────
# Outputs — à récupérer après terraform apply
# ──────────────────────────────────────────────

output "cicd_access_key_id" {
  description = "AWS_ACCESS_KEY_ID → GitHub Actions secret"
  value       = aws_iam_access_key.cicd.id
}

output "cicd_secret_access_key" {
  description = "AWS_SECRET_ACCESS_KEY → GitHub Actions secret"
  value       = aws_iam_access_key.cicd.secret
  sensitive   = true
}
