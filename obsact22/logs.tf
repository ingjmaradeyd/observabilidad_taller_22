resource "aws_cloudwatch_log_group" "service_a" {
  name              = "/ecs/${local.name}/service-a"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "service_b" {
  name              = "/ecs/${local.name}/service-b"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "data_service" {
  name              = "/ecs/${local.name}/data-service"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "service_connect" {
  name              = "/ecs/${local.name}/service-connect"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "rds_migrator" {
  name              = "/ecs/${local.name}/rds-migrator"
  retention_in_days = 7
}
