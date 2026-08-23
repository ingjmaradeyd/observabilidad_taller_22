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
# Collector -> AWS APIs
# ------------------------------------------------------------

resource "aws_vpc_security_group_egress_rule" "adot_outbound" {

  security_group_id = aws_security_group.adot.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}
