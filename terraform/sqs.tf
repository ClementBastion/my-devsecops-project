# ──────────────────────────────────────────────
# SQS — Queue principale + Dead Letter Queue
# La DLQ capture les messages en échec
# après 3 tentatives de traitement
# ──────────────────────────────────────────────

# Dead Letter Queue — messages en échec
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq-${var.environment}"
  message_retention_seconds = 1209600 # 14 jours pour investigation

  tags = {
    Name = "${var.project_name}-dlq-${var.environment}"
  }
}

# Queue principale
resource "aws_sqs_queue" "main" {
  name                       = "${var.project_name}-queue-${var.environment}"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = var.sqs_message_retention

  # Renvoi vers DLQ après 3 échecs
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.project_name}-queue-${var.environment}"
  }
}

# Politique permettant à EventBridge d'écrire dans SQS
resource "aws_sqs_queue_policy" "allow_eventbridge" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowEventBridgeSend"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action   = "sqs:SendMessage"
      Resource = aws_sqs_queue.main.arn
      Condition = {
        ArnEquals = {
          "aws:SourceArn" = aws_cloudwatch_event_rule.lambda_a_events.arn
        }
      }
    }]
  })
}

# Alarme CloudWatch sur la DLQ — alerte si messages bloqués
resource "aws_cloudwatch_metric_alarm" "dlq_not_empty" {
  alarm_name          = "${var.project_name}-dlq-not-empty-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Messages en échec détectés dans la DLQ — investigation requise"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }
}
