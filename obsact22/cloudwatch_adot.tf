resource "aws_cloudwatch_log_group" "adot_container" {

  name = "/ecs/${var.environment}/adot-collector"

  retention_in_days = 7

  tags = {
    Environment = var.environment
    Component   = "adot-collector"
  }
}


resource "aws_cloudwatch_log_group" "otel_application" {

  name = "/otel/${var.environment}/application"

  retention_in_days = 7

  tags = {
    Environment = var.environment
    Component   = "application-observability"
  }
}


resource "aws_cloudwatch_log_stream" "otel_application" {
  name           = "application"
  log_group_name = aws_cloudwatch_log_group.otel_application.name
}
