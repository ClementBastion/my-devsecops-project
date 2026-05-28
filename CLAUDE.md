# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`myftpdr` — an event-driven DevSecOps pipeline on AWS, fully managed by Terraform. Lambda function code lives in `lambda-a/` and `lambda-b/` (currently empty stubs); all infrastructure is declared in `terraform/`.

## Terraform Commands

All commands must be run from the `terraform/` directory. `alert_email` is a required variable with no default.

```bash
cd terraform

# Initialize (first time or after provider changes)
terraform init

# Preview changes
terraform plan -var="alert_email=you@example.com"

# Apply
terraform apply -var="alert_email=you@example.com"

# Destroy
terraform destroy -var="alert_email=you@example.com"
```

Set `TF_VAR_alert_email` in the environment to avoid passing `-var` on every command:
```bash
export TF_VAR_alert_email=you@example.com
```

Override environment or region:
```bash
terraform apply -var="environment=prod" -var="aws_region=eu-west-1"
```

## Architecture

The pipeline is fully event-driven and flows in one direction:

```
Client
  └─► API Gateway v2 (HTTP API)
        ├─ POST /process ─► Lambda A (container image, ECR)
        └─ GET  /health  ─► Lambda A
                                └─► EventBridge (custom bus: myftpdr-bus-<env>)
                                      source: "myftpdr.lambda-a"
                                      detail-type: "ProcessingComplete"
                                          └─► SQS (main queue, batch 10)
                                                └─► Lambda B (container image, ECR)
                                                      └─► SNS (alerts topic → email)
```

**Dead-letter handling**: SQS DLQ captures messages after 3 failed Lambda B attempts. A CloudWatch alarm fires (via SNS) whenever the DLQ is non-empty.

**Observability**: CloudWatch log groups for Lambda A, Lambda B, and API Gateway; metric alarms on Lambda errors and duration (80% of timeout threshold); a dashboard aggregating all four components.

## Key Design Constraints

- **IAM least-privilege**: each Lambda has its own role scoped to exactly the services it needs (Lambda A: EventBridge + ECR pull; Lambda B: SQS consume + SNS publish + ECR pull).
- **ECR images are immutable**: tags cannot be overwritten — the CI/CD pipeline must push a new tag per build. Lambda functions currently reference `:latest` which the pipeline is expected to update.
- **SQS visibility timeout must be ≥ `lambda_timeout_sec × 2`** (default: 60s timeout, 30s lambda). This is enforced by convention, not by Terraform validation.
- **S3 backend is commented out** in `terraform/main.tf`. To enable remote state, create the S3 bucket (`myftpdr-terraform-state`) and DynamoDB table (`myftpdr-terraform-locks`) manually first, then uncomment the `backend "s3"` block and run `terraform init -migrate-state`.
- **SNS email subscription requires manual confirmation** on first `terraform apply` — AWS sends a confirmation email to `alert_email`.
- **API Gateway CORS** is currently open (`allow_origins = ["*"]`) — restrict this before promoting to production.

## Terraform File Layout

| File | Responsibility |
|---|---|
| `main.tf` | Provider config, Terraform version, S3 backend (commented) |
| `variables.tf` | All input variables with defaults |
| `lambda.tf` | ECR repositories (with lifecycle/scan), Lambda functions, SQS event source mapping |
| `iam.tf` | IAM roles and inline policies for Lambda A and Lambda B |
| `apigateway.tf` | HTTP API, stage, integration, routes (`POST /process`, `GET /health`) |
| `eventbridge.tf` | Custom event bus, routing rule (source filter), SQS target |
| `sqs.tf` | Main queue, DLQ, EventBridge-to-SQS queue policy, DLQ alarm |
| `cloudwatch.tf` | Log groups, Lambda/API metric alarms, dashboard |
| `sns.tf` | Alerts topic, email subscription |
| `outputs.tf` | API URLs, ECR URLs, SQS URLs, SNS ARN, EventBridge bus name, dashboard URL |

## CI/CD

`.gitlab-ci.yml` exists but is empty. The intended pipeline should:
1. Build Docker images for `lambda-a` and `lambda-b`
2. Authenticate to ECR (`aws ecr get-login-password`)
3. Push images with an immutable tag (e.g. commit SHA)
4. Update the Lambda function to point to the new image URI
5. Run `terraform plan` / `terraform apply` for infrastructure changes
