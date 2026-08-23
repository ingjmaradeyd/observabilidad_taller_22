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

variable "private_app_subnet_cidrs" {
  description = "Two private application subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Two private database subnet CIDRs, one per AZ."
  type        = list(string)
  default     = ["10.20.21.0/24", "10.20.22.0/24"]
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

variable "service_b_health_path" {
  description = "ALB health check path for service B."
  type        = string
  default     = "/health"
}

variable "service_a_image_tag" {
  description = "ECR image tag for service A."
  type        = string
  default     = "latest"
}

variable "service_b_image_tag" {
  description = "ECR image tag for service B."
  type        = string
  default     = "latest"
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

variable "adot_memory" {
  description = "Memory assigned to ADOT Collector"
  type        = number
  default     = 512
}

variable "adot_desired_count" {
  description = "Number of ADOT Collector tasks"
  type        = number
  default     = 1
}
