resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.environment}.internal"
  description = "Private namespace used by ECS Service Connect."
  vpc         = aws_vpc.main.id
}
