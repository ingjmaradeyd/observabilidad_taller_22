resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Public HTTP entry point for Service A."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-alb-sg"
  }
}

resource "aws_security_group" "service_a" {
  name        = "${local.name}-service-a-sg"
  description = "Private ingress and restricted egress for Service A."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-service-a-sg"
  }
}

resource "aws_security_group" "service_b" {
  name        = "${local.name}-service-b-sg"
  description = "Private ingress and restricted egress for Service B."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-service-b-sg"
  }
}

resource "aws_security_group" "data_service" {
  name        = "${local.name}-data-service-sg"
  description = "Private ingress and restricted egress for data-service."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-data-service-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "PostgreSQL access restricted to Service B and data-service."
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name}-rds-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the Internet."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_service_a" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward requests only to Service A."
  referenced_security_group_id = aws_security_group.service_a.id
  from_port                    = var.service_a_port
  to_port                      = var.service_a_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "service_a_from_alb" {
  security_group_id            = aws_security_group.service_a.id
  description                  = "Service A traffic from the ALB."
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.service_a_port
  to_port                      = var.service_a_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_a_to_service_b" {
  security_group_id            = aws_security_group.service_a.id
  description                  = "Private requests from Service A to Service B."
  referenced_security_group_id = aws_security_group.service_b.id
  from_port                    = var.service_b_port
  to_port                      = var.service_b_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_a_to_data_service" {
  security_group_id            = aws_security_group.service_a.id
  description                  = "Private requests from Service A to data-service."
  referenced_security_group_id = aws_security_group.data_service.id
  from_port                    = var.data_service_port
  to_port                      = var.data_service_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_a_https" {
  security_group_id = aws_security_group.service_a.id
  description       = "HTTPS to required AWS and external services."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_a_dns_tcp" {
  security_group_id = aws_security_group.service_a.id
  description       = "DNS over TCP through the VPC resolver."
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_a_dns_udp" {
  security_group_id = aws_security_group.service_a.id
  description       = "DNS over UDP through the VPC resolver."
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "service_b_from_service_a" {
  security_group_id            = aws_security_group.service_b.id
  description                  = "Service B traffic only from Service A."
  referenced_security_group_id = aws_security_group.service_a.id
  from_port                    = var.service_b_port
  to_port                      = var.service_b_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_b_to_rds" {
  security_group_id            = aws_security_group.service_b.id
  description                  = "PostgreSQL traffic from Service B to RDS."
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_b_https" {
  security_group_id = aws_security_group.service_b.id
  description       = "HTTPS to required AWS and external services."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_b_dns_tcp" {
  security_group_id = aws_security_group.service_b.id
  description       = "DNS over TCP through the VPC resolver."
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "service_b_dns_udp" {
  security_group_id = aws_security_group.service_b.id
  description       = "DNS over UDP through the VPC resolver."
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "data_service_from_service_a" {
  security_group_id            = aws_security_group.data_service.id
  description                  = "data-service traffic only from Service A."
  referenced_security_group_id = aws_security_group.service_a.id
  from_port                    = var.data_service_port
  to_port                      = var.data_service_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "data_service_to_rds" {
  security_group_id            = aws_security_group.data_service.id
  description                  = "PostgreSQL traffic from data-service to RDS."
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "data_service_https" {
  security_group_id = aws_security_group.data_service.id
  description       = "HTTPS to required AWS and external services."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "data_service_dns_tcp" {
  security_group_id = aws_security_group.data_service.id
  description       = "DNS over TCP through the VPC resolver."
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "data_service_dns_udp" {
  security_group_id = aws_security_group.data_service.id
  description       = "DNS over UDP through the VPC resolver."
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_service_b" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL only from Service B."
  referenced_security_group_id = aws_security_group.service_b.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_data_service" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL only from data-service."
  referenced_security_group_id = aws_security_group.data_service.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}
