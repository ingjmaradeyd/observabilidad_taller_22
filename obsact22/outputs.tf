output "vpc_id" {
  description = "ID of the laboratory VPC."
  value       = aws_vpc.main.id
}

output "availability_zones" {
  description = "Availability Zones used by the laboratory subnets."
  value       = local.azs
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer."
  value       = aws_lb.app.dns_name
}

output "service_a_url" {
  description = "Public Service A URL exposed through the Application Load Balancer."
  value       = "http://${aws_lb.app.dns_name}/service-a"
}

output "service_a_ecr_repository_url" {
  description = "ECR repository URL for Service A."
  value       = aws_ecr_repository.service_a.repository_url
}

output "service_b_ecr_repository_url" {
  description = "ECR repository URL for Service B."
  value       = aws_ecr_repository.service_b.repository_url
}

output "data_service_ecr_repository_url" {
  description = "ECR repository URL for data-service."
  value       = aws_ecr_repository.data_service.repository_url
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster that runs the laboratory services."
  value       = aws_ecs_cluster.main.name
}

output "service_connect_namespace_arn" {
  description = "ARN of the private Cloud Map namespace used by ECS Service Connect."
  value       = aws_service_discovery_private_dns_namespace.main.arn
}

output "service_connect_namespace_name" {
  description = "Name of the private namespace used by ECS Service Connect."
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "service_b_ecs_service_name" {
  description = "ECS service name for the private Service Connect server Service B."
  value       = aws_ecs_service.service_b.name
}

output "data_service_ecs_service_name" {
  description = "ECS service name for the private Service Connect server data-service."
  value       = aws_ecs_service.data_service.name
}

output "rds_endpoint" {
  description = "Private endpoint of the PostgreSQL RDS instance."
  value       = aws_db_instance.postgres.endpoint
}

output "rds_master_secret_arn" {
  description = "ARN of the RDS-managed master credential secret."
  value       = aws_db_instance.postgres.master_user_secret[0].secret_arn
  sensitive   = true
}
