data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "vpc_flow_logs_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:vpc-flow-log/*"]
    }
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/vpc/${local.name}/flow-logs"
  retention_in_days = 3

  tags = {
    Name = "${local.name}-vpc-flow-logs"
  }
}

data "aws_iam_policy_document" "vpc_flow_logs_permissions" {
  statement {
    sid    = "PublishFlowLogs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  name               = "${local.name}-vpc-flow-logs-role"
  description        = "Publishes VPC Flow Logs to the dedicated CloudWatch log group."
  assume_role_policy = data.aws_iam_policy_document.vpc_flow_logs_assume_role.json

  tags = {
    Name = "${local.name}-vpc-flow-logs-role"
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name   = "${local.name}-vpc-flow-logs"
  role   = aws_iam_role.vpc_flow_logs.id
  policy = data.aws_iam_policy_document.vpc_flow_logs_permissions.json
}

resource "aws_flow_log" "vpc" {
  iam_role_arn             = aws_iam_role.vpc_flow_logs.arn
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type     = "cloud-watch-logs"
  max_aggregation_interval = 60
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.main.id

  tags = {
    Name = "${local.name}-vpc-flow-log"
  }

  depends_on = [aws_iam_role_policy.vpc_flow_logs]
}

resource "aws_cloudwatch_log_metric_filter" "vpc_flow_log_rejects" {
  name           = "${local.name}-vpc-flow-log-rejects"
  pattern        = "[version, accountid, interfaceid, srcaddr, dstaddr, srcport, dstport, protocol, packets, bytes, start, end, action = REJECT, logstatus]"
  log_group_name = aws_cloudwatch_log_group.vpc_flow_logs.name

  metric_transformation {
    name          = "RejectedFlowLogRecords"
    namespace     = "${local.name}/Network"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_metric_alarm" "vpc_flow_log_rejects" {
  alarm_name          = "${local.name}-vpc-flow-log-rejects"
  alarm_description   = "Signals rejected network traffic recorded by VPC Flow Logs."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = aws_cloudwatch_log_metric_filter.vpc_flow_log_rejects.metric_transformation[0].name
  namespace           = aws_cloudwatch_log_metric_filter.vpc_flow_log_rejects.metric_transformation[0].namespace
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
}
