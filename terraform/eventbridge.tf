# ──────────────────────────────────────────────
# EventBridge — Bus custom + règle de routing
# Lambda A publie → EventBridge filtre
# → SQS reçoit uniquement les bons événements
# ──────────────────────────────────────────────

# Bus d'événements dédié au projet (isolation du bus default)
resource "aws_cloudwatch_event_bus" "main" {
  name = "${var.project_name}-bus-${var.environment}"
}

# Règle : capture tous les events source "myftpdr.lambda-a"
resource "aws_cloudwatch_event_rule" "lambda_a_events" {
  name           = "${var.project_name}-lambda-a-events-${var.environment}"
  description    = "Route les événements de Lambda A vers SQS"
  event_bus_name = aws_cloudwatch_event_bus.main.name

  event_pattern = jsonencode({
    source      = ["${var.project_name}.lambda-a"]
    detail-type = ["ProcessingComplete"]
  })
}

# Cible de la règle : notre queue SQS
resource "aws_cloudwatch_event_target" "sqs" {
  rule           = aws_cloudwatch_event_rule.lambda_a_events.name
  event_bus_name = aws_cloudwatch_event_bus.main.name
  target_id      = "SendToSQS"
  arn            = aws_sqs_queue.main.arn
}
