resource "aws_service_discovery_private_dns_namespace" "observability" {

  name = "observability.local"

  description = "Private service discovery namespace for observability"

  vpc = aws_vpc.main.id

  tags = {
    Environment = var.environment
  }
}


resource "aws_service_discovery_service" "adot" {

  name = "adot-collector"

  dns_config {

    namespace_id = aws_service_discovery_private_dns_namespace.observability.id

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
