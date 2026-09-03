resource "aws_cloudwatch_log_metric_filter" "data_service_chaos_errors" {
  name           = "${local.name}-data-service-chaos-errors"
  pattern        = "\"Controlled order failure injected\""
  log_group_name = aws_cloudwatch_log_group.otel_application.name

  metric_transformation {
    name          = "DataServiceChaosErrors"
    namespace     = "${local.name}/AIOps"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "data_service_chaos_errors_static" {
  alarm_name          = "${local.name}-data-service-chaos-errors-static"
  alarm_description   = "Control alarm for one or more controlled data-service order failures in one minute."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.data_service_chaos_errors.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.data_service_chaos_errors.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "data_service_chaos_errors_anomaly" {
  alarm_name          = "${local.name}-data-service-chaos-errors-anomaly"
  alarm_description   = "Detects data-service controlled-order failures outside the CloudWatch two-standard-deviation anomaly band."
  comparison_operator = "GreaterThanUpperThreshold"
  evaluation_periods  = 1
  threshold_metric_id = "ad1"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "m1"
    return_data = true

    metric {
      metric_name = aws_cloudwatch_log_metric_filter.data_service_chaos_errors.metric_transformation[0].name
      namespace   = aws_cloudwatch_log_metric_filter.data_service_chaos_errors.metric_transformation[0].namespace
      period      = 60
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "ad1"
    expression  = "ANOMALY_DETECTION_BAND(m1, 2)"
    label       = "Data-service controlled-error anomaly band"
    return_data = true
  }
}
