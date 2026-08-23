resource "aws_cloudwatch_log_group" "service_a" {
  name              = "/ecs/${local.name}/service-a"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "service_b" {
  name              = "/ecs/${local.name}/service-b"
  retention_in_days = 7
}
