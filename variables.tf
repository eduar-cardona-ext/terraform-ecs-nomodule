variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "nginx-ecs-demo"
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default = [
    "10.0.1.0/24",
    "10.0.2.0/24"
  ]
}

variable "acm_certificate_arn" {
  description = "ARN of an existing ACM certificate in this region for the ALB HTTPS listener"
  type        = string
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = string
  default     = "256" # 0.25 vCPU
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = string
  default     = "512"
}