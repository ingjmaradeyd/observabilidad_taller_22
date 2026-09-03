resource "aws_security_group" "adot" {

  name        = "${var.environment}-adot-sg"
  description = "Security group for ADOT Collector"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "${var.environment}-adot-sg"
    Environment = var.environment
  }
}


# ------------------------------------------------------------
# service-a -> OTLP gRPC
# ------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "service_a_to_adot_grpc" {

  security_group_id = aws_security_group.adot.id

  referenced_security_group_id = aws_security_group.service_a.id

  from_port   = 4317
  to_port     = 4317
  ip_protocol = "tcp"
}


# ------------------------------------------------------------
# service-a -> OTLP HTTP
# ------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "service_a_to_adot_http" {

  security_group_id = aws_security_group.adot.id

  referenced_security_group_id = aws_security_group.service_a.id

  from_port   = 4318
  to_port     = 4318
  ip_protocol = "tcp"
}


# ------------------------------------------------------------
# service-b -> OTLP gRPC
# ------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "service_b_to_adot_grpc" {

  security_group_id = aws_security_group.adot.id

  referenced_security_group_id = aws_security_group.service_b.id

  from_port   = 4317
  to_port     = 4317
  ip_protocol = "tcp"
}


# ------------------------------------------------------------
# service-b -> OTLP HTTP
# ------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "service_b_to_adot_http" {

  security_group_id = aws_security_group.adot.id

  referenced_security_group_id = aws_security_group.service_b.id

  from_port   = 4318
  to_port     = 4318
  ip_protocol = "tcp"
}


# ------------------------------------------------------------
# data-service -> OTLP gRPC
# ------------------------------------------------------------

resource "aws_vpc_security_group_ingress_rule" "data_service_to_adot_grpc" {

  security_group_id = aws_security_group.adot.id

  description                  = "OTLP gRPC telemetry from data-service."
  referenced_security_group_id = aws_security_group.data_service.id

  from_port   = 4317
  to_port     = 4317
  ip_protocol = "tcp"
}


# ------------------------------------------------------------
# Collector -> AWS APIs
# ------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "adot_https" {

  security_group_id = aws_security_group.adot.id

  description = "HTTPS to AWS telemetry and runtime services"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}


# ------------------------------------------------------------
# Collector -> VPC DNS resolver
# ------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "adot_dns_tcp" {

  security_group_id = aws_security_group.adot.id

  description = "DNS over TCP through the VPC resolver"
  cidr_ipv4   = var.vpc_cidr
  from_port   = 53
  to_port     = 53
  ip_protocol = "tcp"
}


resource "aws_vpc_security_group_egress_rule" "adot_dns_udp" {

  security_group_id = aws_security_group.adot.id

  description = "DNS over UDP through the VPC resolver"
  cidr_ipv4   = var.vpc_cidr
  from_port   = 53
  to_port     = 53
  ip_protocol = "udp"
}
