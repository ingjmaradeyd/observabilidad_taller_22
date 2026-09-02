variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used in resource names."
  type        = string
  default     = "otel-fargate-lab"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "lab"
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Two private database subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.20.21.0/24", "10.20.22.0/24"]
}

variable "data_service_cpu" {
  description = "Fargate CPU units assigned to data-service."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.data_service_cpu)
    error_message = "data-service CPU must be a supported Fargate CPU value."
  }
}

variable "data_service_desired_count" {
  description = "Desired number of data-service tasks. Keep 0 until the image is pushed and RDS is initialized."
  type        = number
  default     = 0

  validation {
    condition     = var.data_service_desired_count >= 0 && floor(var.data_service_desired_count) == var.data_service_desired_count
    error_message = "data-service desired count must be a non-negative integer."
  }
}

variable "data_service_health_path" {
  description = "Container health check path for data-service."
  type        = string
  default     = "/health"

  validation {
    condition     = startswith(var.data_service_health_path, "/")
    error_message = "data-service health path must start with '/'."
  }
}

variable "data_service_image_tag" {
  description = "Immutable ECR image tag for data-service, using a short Git SHA for development or v1.0.0 for the final release."
  type        = string

  validation {
    condition     = can(regex("^([0-9a-f]{7,12}|v1\\.0\\.0)$", var.data_service_image_tag))
    error_message = "data-service image tag must be a 7-12 character lowercase Git SHA or v1.0.0; empty and latest are not allowed."
  }
}

variable "data_service_memory" {
  description = "Fargate memory in MiB assigned to data-service."
  type        = number
  default     = 512

  validation {
    condition     = var.data_service_memory >= 512 && floor(var.data_service_memory) == var.data_service_memory
    error_message = "data-service memory must be an integer of at least 512 MiB."
  }
}

variable "data_service_port" {
  description = "Private HTTP port exposed by data-service."
  type        = number
  default     = 8002

  validation {
    condition     = var.data_service_port >= 1 && var.data_service_port <= 65535 && floor(var.data_service_port) == var.data_service_port
    error_message = "data-service port must be an integer between 1 and 65535."
  }
}

variable "service_a_port" {
  description = "HTTP port exposed by service A."
  type        = number
  default     = 8000
}

variable "service_b_port" {
  description = "HTTP port exposed by service B."
  type        = number
  default     = 8001
}

variable "service_a_health_path" {
  description = "ALB health check path for service A."
  type        = string
  default     = "/health"
}

variable "service_a_image_tag" {
  description = "Immutable ECR image tag for service A, using a short Git SHA for development or v1.0.0 for the final release."
  type        = string

  validation {
    condition     = can(regex("^([0-9a-f]{7,12}|v1\\.0\\.0)$", var.service_a_image_tag))
    error_message = "Service A image tag must be a 7-12 character lowercase Git SHA or v1.0.0; empty and latest are not allowed."
  }
}

variable "service_b_image_tag" {
  description = "Immutable ECR image tag for service B, using a short Git SHA for development or v1.0.0 for the final release."
  type        = string

  validation {
    condition     = can(regex("^([0-9a-f]{7,12}|v1\\.0\\.0)$", var.service_b_image_tag))
    error_message = "Service B image tag must be a 7-12 character lowercase Git SHA or v1.0.0; empty and latest are not allowed."
  }
}

variable "service_a_desired_count" {
  description = "Desired number of service A tasks. Keep 0 until the image is pushed."
  type        = number
  default     = 0
}

variable "service_b_desired_count" {
  description = "Desired number of service B tasks. Keep 0 until the image is pushed."
  type        = number
  default     = 0
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "appadmin"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GiB."
  type        = number
  default     = 20
}

variable "db_multi_az" {
  description = "Enable RDS Multi-AZ."
  type        = bool
  default     = false
}

variable "adot_cpu" {
  description = "CPU units assigned to ADOT Collector"
  type        = number
  default     = 256
}

variable "adot_image_tag" {
  description = "Immutable ECR image tag for ADOT Collector, using a short Git SHA for development or v1.0.0 for the final release."
  type        = string

  validation {
    condition     = can(regex("^([0-9a-f]{7,12}|v1\\.0\\.0)$", var.adot_image_tag))
    error_message = "ADOT Collector image tag must be a 7-12 character lowercase Git SHA or v1.0.0; empty and latest are not allowed."
  }
}

variable "adot_memory" {
  description = "Memory assigned to ADOT Collector"
  type        = number
  default     = 512
}

variable "adot_desired_count" {
  description = "Number of ADOT Collector tasks"
  type        = number
  default     = 0
}
