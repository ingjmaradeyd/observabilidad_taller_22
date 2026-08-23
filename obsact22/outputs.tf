output "vpc_id" {
  value = aws_vpc.main.id
}

output "availability_zones" {
  value = local.azs
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "service_a_url" {
  value = "http://${aws_lb.app.dns_name}/service-a"
}

output "service_b_url" {
  value = "http://${aws_lb.app.dns_name}/service-b"
}

output "service_b_private_url" {
  value = "http://service-b.${aws_service_discovery_private_dns_namespace.main.name}:${var.service_b_port}"
}

output "service_a_ecr_repository_url" {
  value = aws_ecr_repository.service_a.repository_url
}

output "service_b_ecr_repository_url" {
  value = aws_ecr_repository.service_b.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "rds_master_secret_arn" {
  value     = aws_db_instance.postgres.master_user_secret[0].secret_arn
  sensitive = true
}
