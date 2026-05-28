# ──────────────────────────────────────────────
# IAM — Utilisateur CI/CD GitHub Actions
# À appliquer UNE SEULE FOIS avec des credentials admin.
# NE PAS inclure dans le pipeline CI/CD.
# ──────────────────────────────────────────────

locals {
  project_name = "myftpdr"
  aws_region   = "eu-west-3"
}

resource "aws_iam_user" "cicd" {
  name = "${local.project_name}-cicd"
  tags = { Name = "${local.project_name}-cicd" }
}

resource "aws_iam_access_key" "cicd" {
  user = aws_iam_user.cicd.name
}

resource "aws_iam_policy" "cicd" {
  name        = "${local.project_name}-cicd-policy"
  description = "Permissions CI/CD GitHub Actions pour ${local.project_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # ── Terraform state ──────────────────────────────────────────────
      {
        Sid    = "TerraformStateS3"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${local.project_name}-terraform-state",
          "arn:aws:s3:::${local.project_name}-terraform-state/*"
        ]
      },
      {
        Sid      = "TerraformLockDynamoDB"
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:${local.aws_region}:*:table/${local.project_name}-terraform-locks"
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
        Resource = "arn:aws:ecr:${local.aws_region}:*:repository/${local.project_name}/*"
      },

      # ── Lambda ───────────────────────────────────────────────────────
      {
        Sid    = "LambdaManagement"
        Effect = "Allow"
        Action = [
          "lambda:CreateFunction", "lambda:DeleteFunction",
          "lambda:GetFunction", "lambda:GetFunctionConfiguration",
          "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration",
          "lambda:AddPermission", "lambda:RemovePermission", "lambda:GetPolicy",
          "lambda:ListVersionsByFunction",
          "lambda:TagResource", "lambda:UntagResource", "lambda:ListTags"
        ]
        Resource = "arn:aws:lambda:${local.aws_region}:*:function:${local.project_name}-*"
      },
      {
        Sid    = "LambdaEventSourceMapping"
        Effect = "Allow"
        Action = [
          "lambda:CreateEventSourceMapping", "lambda:UpdateEventSourceMapping",
          "lambda:DeleteEventSourceMapping", "lambda:GetEventSourceMapping",
          "lambda:ListEventSourceMappings"
        ]
        Resource = "*"
      },

      # ── API Gateway v2 ───────────────────────────────────────────────
      {
        Sid      = "APIGateway"
        Effect   = "Allow"
        Action   = "apigateway:*"
        Resource = [
          "arn:aws:apigateway:${local.aws_region}::/apis",
          "arn:aws:apigateway:${local.aws_region}::/apis/*"
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
          "events:ListTagsForResource", "events:TagResource", "events:UntagResource"
        ]
        Resource = [
          "arn:aws:events:${local.aws_region}:*:event-bus/${local.project_name}-*",
          "arn:aws:events:${local.aws_region}:*:rule/${local.project_name}-*",
          "arn:aws:events:${local.aws_region}:*:rule/${local.project_name}-*/*"
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
        Resource = "arn:aws:sqs:${local.aws_region}:*:${local.project_name}-*"
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
          "sns:ListTagsForResource", "sns:TagResource", "sns:UntagResource"
        ]
        Resource = "arn:aws:sns:${local.aws_region}:*:${local.project_name}-*"
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
        Resource = "arn:aws:iam::*:role/${local.project_name}-*"
      },
      {
        Sid      = "IAMPassRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "arn:aws:iam::*:role/${local.project_name}-*"
        Condition = {
          StringEquals = { "iam:PassedToService" = "lambda.amazonaws.com" }
        }
      },

      # ── CloudWatch Logs ───────────────────────────────────────────────
      {
        Sid    = "CloudWatchLogsDescribe"
        Effect = "Allow"
        # DescribeLogGroups est appelé par le provider TF avec un filtre global,
        # AWS évalue la permission sur "*" indépendamment du filtre envoyé
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup", "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy",
          "logs:ListTagsForResource", "logs:TagResource", "logs:UntagResource"
        ]
        Resource = [
          "arn:aws:logs:${local.aws_region}:*:log-group:/aws/lambda/${local.project_name}-*",
          "arn:aws:logs:${local.aws_region}:*:log-group:/aws/apigateway/${local.project_name}-*"
        ]
      },

      # ── CloudWatch Alarms + Dashboard ─────────────────────────────────
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm", "cloudwatch:DeleteAlarms", "cloudwatch:DescribeAlarms",
          "cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards", "cloudwatch:GetDashboard",
          "cloudwatch:ListTagsForResource", "cloudwatch:TagResource", "cloudwatch:UntagResource"
        ]
        Resource = [
          "arn:aws:cloudwatch::*:dashboard/${local.project_name}-*",
          "arn:aws:cloudwatch:${local.aws_region}:*:alarm:${local.project_name}-*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "cicd" {
  user       = aws_iam_user.cicd.name
  policy_arn = aws_iam_policy.cicd.arn
}

output "cicd_access_key_id" {
  description = "AWS_ACCESS_KEY_ID → GitHub Actions secret"
  value       = aws_iam_access_key.cicd.id
}

output "cicd_secret_access_key" {
  description = "AWS_SECRET_ACCESS_KEY → GitHub Actions secret"
  value       = aws_iam_access_key.cicd.secret
  sensitive   = true
}
