# ──────────────────────────────────────────────
# SNS — Topic d'alertes et notifications
# Utilisé par Lambda B pour notifier
# et par CloudWatch pour les alarmes
# ──────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts-${var.environment}"
}

# Abonnement email (confirmation manuelle requise au 1er apply)
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
