output "api_gateway_url" {
  description = "URL de l'API Gateway"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/process"
}

output "api_gateway_health_url" {
  description = "URL du healthcheck"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/health"
}

output "ecr_lambda_a_url" {
  description = "URL ECR Lambda A (pour le pipeline CI/CD)"
  value       = aws_ecr_repository.lambda_a.repository_url
}

output "ecr_lambda_b_url" {
  description = "URL ECR Lambda B (pour le pipeline CI/CD)"
  value       = aws_ecr_repository.lambda_b.repository_url
}

output "sqs_queue_url" {
  description = "URL de la queue SQS principale"
  value       = aws_sqs_queue.main.id
}

output "sqs_dlq_url" {
  description = "URL de la Dead Letter Queue"
  value       = aws_sqs_queue.dlq.id
}

output "sns_topic_arn" {
  description = "ARN du topic SNS"
  value       = aws_sns_topic.alerts.arn
}

output "event_bus_name" {
  description = "Nom du bus EventBridge"
  value       = aws_cloudwatch_event_bus.main.name
}

output "cloudwatch_dashboard_url" {
  description = "URL du dashboard CloudWatch"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}
