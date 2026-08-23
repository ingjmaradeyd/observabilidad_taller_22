resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.environment}.internal"
  description = "Private service discovery namespace for ECS."
  vpc         = aws_vpc.main.id
}

resource "aws_service_discovery_service" "service_b" {
  name = "service-b"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  lifecycle {
    ignore_changes = [
      health_check_custom_config
    ]
  }
}
