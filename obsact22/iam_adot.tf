
data "aws_iam_policy_document" "ecs_task_assume_role" {

  statement {

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}


# ============================================================
# ECS EXECUTION ROLE
# Used by ECS itself:
# - Pull image from ECR
# - CloudWatch container logs
# ============================================================

resource "aws_iam_role" "adot_execution_role" {

  name = "${var.environment}-adot-execution-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Environment = var.environment
    Component   = "adot-collector"
  }
}


resource "aws_iam_role_policy_attachment" "adot_execution_role_policy" {

  role = aws_iam_role.adot_execution_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# ============================================================
# ADOT TASK ROLE
#
# Used INSIDE the ADOT container.
# No Access Key / Secret Key required.
# ============================================================

resource "aws_iam_role" "adot_task_role" {

  name = "${var.environment}-adot-task-role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json

  tags = {
    Environment = var.environment
    Component   = "adot-collector"
  }
}


resource "aws_iam_role_policy_attachment" "adot_cloudwatch_policy" {

  role = aws_iam_role.adot_task_role.name

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}
