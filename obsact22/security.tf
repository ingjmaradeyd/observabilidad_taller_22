resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  description = "Internet traffic to the ALB."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "ALB outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-alb-sg"
  }
}

resource "aws_security_group" "service_a" {
  name        = "${local.name}-service-a-sg"
  description = "Traffic to service A."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "ALB to service A"
    from_port       = var.service_a_port
    to_port         = var.service_a_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Service A outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-service-a-sg"
  }
}

resource "aws_security_group" "service_b" {
  name        = "${local.name}-service-b-sg"
  description = "Traffic to service B."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "ALB to service B"
    from_port       = var.service_b_port
    to_port         = var.service_b_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Service A to service B"
    from_port       = var.service_b_port
    to_port         = var.service_b_port
    protocol        = "tcp"
    security_groups = [aws_security_group.service_a.id]
  }

  egress {
    description = "Service B outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-service-b-sg"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  description = "PostgreSQL access from both microservices."
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from service A"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.service_a.id]
  }

  ingress {
    description     = "PostgreSQL from service B"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.service_b.id]
  }

  egress {
    description = "RDS outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-rds-sg"
  }
}
