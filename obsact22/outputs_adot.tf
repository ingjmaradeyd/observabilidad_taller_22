output "adot_ecr_repository_url" {

  description = "ECR repository URL for ADOT Collector"

  value = aws_ecr_repository.adot_collector.repository_url

}


output "adot_service_discovery_endpoint" {

  description = "Internal DNS endpoint used by applications"

  value = "adot-collector.observability.local"

}


output "adot_otlp_grpc_endpoint" {

  description = "OTLP gRPC endpoint"

  value = "adot-collector.observability.local:4317"

}


output "adot_otlp_http_endpoint" {

  description = "OTLP HTTP endpoint"

  value = "http://adot-collector.observability.local:4318"

}


output "adot_task_role_arn" {

  value = aws_iam_role.adot_task_role.arn

}


output "application_log_group" {

  value = aws_cloudwatch_log_group.otel_application.name

}
