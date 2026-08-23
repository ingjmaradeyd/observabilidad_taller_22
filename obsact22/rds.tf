resource "aws_db_subnet_group" "postgres" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name = "${local.name}-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${local.name}-postgres"

  engine                      = "postgres"
  instance_class              = var.db_instance_class
  allocated_storage           = var.db_allocated_storage
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  publicly_accessible     = false
  multi_az                = var.db_multi_az
  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "${local.name}-postgres"
  }
}
