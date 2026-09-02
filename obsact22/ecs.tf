resource "aws_ecs_cluster" "main" {
  name = "${local.name}-cluster"
}

resource "aws_ecs_task_definition" "service_a" {
  family                   = "${local.name}-service-a"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.service_a_execution.arn
  task_role_arn            = aws_iam_role.service_a_task.arn

  container_definitions = jsonencode([
    {
      name      = "service-a"
      image     = "${aws_ecr_repository.service_a.repository_url}:${var.service_a_image_tag}"
      essential = true

      portMappings = [
        {
          name          = "service-a-http"
          containerPort = var.service_a_port
          hostPort      = var.service_a_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "SERVICE_B_URL"
          value = "http://service-b:${var.service_b_port}"
        },
        {
          name  = "DATA_SERVICE_URL"
          value = "http://data-service:${var.data_service_port}"
        },
        {
          name  = "OTEL_ENABLED"
          value = "false"
        },
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "adot-collector.${aws_service_discovery_private_dns_namespace.observability.name}:4317"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.service_a.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_ecs_task_definition" "service_b" {
  family                   = "${local.name}-service-b"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.task_cpu)
  memory                   = tostring(var.task_memory)
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "service-b"
      image     = "${aws_ecr_repository.service_b.repository_url}:${var.service_b_image_tag}"
      essential = true

      portMappings = [
        {
          name          = "service-b-http"
          containerPort = var.service_b_port
          hostPort      = var.service_b_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.postgres.address
        },
        {
          name  = "DB_PORT"
          value = tostring(aws_db_instance.postgres.port)
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "OTEL_ENABLED"
          value = "false"
        },
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "adot-collector.${aws_service_discovery_private_dns_namespace.observability.name}:4317"
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.service_b_port}/health', timeout=2).read()\""
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.service_b.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_ecs_task_definition" "data_service" {
  family                   = "${local.name}-data-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.data_service_cpu)
  memory                   = tostring(var.data_service_memory)
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "data-service"
      image     = "${aws_ecr_repository.data_service.repository_url}:${var.data_service_image_tag}"
      essential = true

      portMappings = [
        {
          name          = "data-service-http"
          containerPort = var.data_service_port
          hostPort      = var.data_service_port
          protocol      = "tcp"
          appProtocol   = "http"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.postgres.address
        },
        {
          name  = "DB_PORT"
          value = tostring(aws_db_instance.postgres.port)
        },
        {
          name  = "DB_NAME"
          value = var.db_name
        },
        {
          name  = "DB_USER"
          value = var.db_username
        },
        {
          name  = "OTEL_ENABLED"
          value = "false"
        },
        {
          name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
          value = "adot-collector.${aws_service_discovery_private_dns_namespace.observability.name}:4317"
        },
        {
          name  = "CHAOS_ENABLED"
          value = "false"
        }
      ]

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_db_instance.postgres.master_user_secret[0].secret_arn}:password::"
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "python -c \"import urllib.request; urllib.request.urlopen('http://127.0.0.1:${var.data_service_port}${var.data_service_health_path}', timeout=2).read()\""
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-group         = aws_cloudwatch_log_group.data_service.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
}

resource "aws_ecs_service" "service_a" {
  name            = "${local.name}-service-a"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_a.arn
  desired_count   = var.service_a_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.service_a.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.main.arn

    log_configuration {
      log_driver = "awslogs"

      options = {
        awslogs-group         = aws_cloudwatch_log_group.service_connect.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "service-a"
      }
    }
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service_a.arn
    container_name   = "service-a"
    container_port   = var.service_a_port
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.service_a_execution_managed
  ]
}

resource "aws_ecs_service" "service_b" {
  name            = "${local.name}-service-b"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.service_b.arn
  desired_count   = var.service_b_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.service_b.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.main.arn

    log_configuration {
      log_driver = "awslogs"

      options = {
        awslogs-group         = aws_cloudwatch_log_group.service_connect.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "service-b"
      }
    }

    service {
      port_name      = "service-b-http"
      discovery_name = "service-b"

      client_alias {
        dns_name = "service-b"
        port     = var.service_b_port
      }
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_managed,
    aws_iam_role_policy.ecs_execution_secrets
  ]
}

resource "aws_ecs_service" "data_service" {
  name            = "${local.name}-data-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.data_service.arn
  desired_count   = var.data_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.data_service.id]
    assign_public_ip = true
  }

  service_connect_configuration {
    enabled   = true
    namespace = aws_service_discovery_private_dns_namespace.main.arn

    log_configuration {
      log_driver = "awslogs"

      options = {
        awslogs-group         = aws_cloudwatch_log_group.service_connect.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "data-service"
      }
    }

    service {
      port_name      = "data-service-http"
      discovery_name = "data-service"

      client_alias {
        dns_name = "data-service"
        port     = var.data_service_port
      }
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_managed,
    aws_iam_role_policy.ecs_execution_secrets
  ]
}
