resource "aws_ecs_task_definition" "adot" {

  family = "${var.environment}-adot-collector"

  requires_compatibilities = [
    "FARGATE"
  ]

  network_mode = "awsvpc"

  cpu    = tostring(var.adot_cpu)
  memory = tostring(var.adot_memory)

  execution_role_arn = aws_iam_role.adot_execution_role.arn
  task_role_arn      = aws_iam_role.adot_task_role.arn


  container_definitions = jsonencode([
    {

      name = "adot-collector"

      image = "${aws_ecr_repository.adot_collector.repository_url}:latest"

      essential = true


      portMappings = [

        {
          name          = "otlp-grpc"
          containerPort = 4317
          hostPort      = 4317
          protocol      = "tcp"
        },

        {
          name          = "otlp-http"
          containerPort = 4318
          hostPort      = 4318
          protocol      = "tcp"
        }

      ]


      environment = [

        {
          name  = "AWS_REGION"
          value = var.aws_region
        },

        {
          name  = "DEPLOYMENT_ENVIRONMENT"
          value = var.environment
        },

        {
          name  = "OTEL_LOG_GROUP"
          value = aws_cloudwatch_log_group.otel_application.name
        },

        {
          name  = "OTEL_LOG_STREAM"
          value = aws_cloudwatch_log_stream.otel_application.name
        }

      ]


      logConfiguration = {

        logDriver = "awslogs"

        options = {

          awslogs-group = aws_cloudwatch_log_group.adot_container.name

          awslogs-region = var.aws_region

          awslogs-stream-prefix = "adot"

        }

      }

    }

  ])


  tags = {

    Environment = var.environment

    Component = "adot-collector"

  }

}


resource "aws_ecs_service" "adot" {

  name = "${var.environment}-adot-collector"

  cluster = aws_ecs_cluster.main.id

  task_definition = aws_ecs_task_definition.adot.arn

  desired_count = var.adot_desired_count

  launch_type = "FARGATE"


  network_configuration {

    subnets = aws_subnet.private_app[*].id

    security_groups = [
      aws_security_group.adot.id
    ]

    assign_public_ip = false

  }


  service_registries {

    registry_arn = aws_service_discovery_service.adot.arn

  }


  depends_on = [

    aws_iam_role_policy_attachment.adot_execution_role_policy,

    aws_iam_role_policy_attachment.adot_cloudwatch_policy

  ]

}
