variable "aws_region" {
  description = "Région AWS cible"
  type        = string
  default     = "eu-west-3" # Paris
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "myftpdr"
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "alert_email" {
  description = "Email pour les alertes SNS"
  type        = string
  # À surcharger via TF_VAR_alert_email ou terraform.tfvars
}

variable "lambda_memory_mb" {
  description = "Mémoire allouée aux lambdas (Mo)"
  type        = number
  default     = 128
}

variable "lambda_timeout_sec" {
  description = "Timeout des lambdas (secondes)"
  type        = number
  default     = 30
}

variable "sqs_visibility_timeout" {
  description = "Durée de visibilité SQS (secondes)"
  type        = number
  default     = 60 # Doit être >= lambda_timeout_sec * 2
}

variable "sqs_message_retention" {
  description = "Rétention des messages SQS (secondes)"
  type        = number
  default     = 86400 # 24h
}

variable "cloudwatch_retention_days" {
  description = "Rétention des logs CloudWatch (jours)"
  type        = number
  default     = 14
}
