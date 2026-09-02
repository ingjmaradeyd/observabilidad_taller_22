resource "aws_ecr_repository" "service_a" {
  name                 = "${local.name}-service-a"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Component = "service-a"
  }
}

resource "aws_ecr_repository" "service_b" {
  name                 = "${local.name}-service-b"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Component = "service-b"
  }
}

resource "aws_ecr_repository" "data_service" {
  name                 = "${local.name}-data-service"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Component = "data-service"
  }
}

resource "aws_ecr_repository" "adot_collector" {
  name                 = "${local.name}-adot-collector"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Component = "adot-collector"
  }
}
