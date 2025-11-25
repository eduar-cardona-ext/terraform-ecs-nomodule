terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

########################
# Data & Locals
########################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  project_name = var.project_name
  tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Simple nginx config and index.html
  nginx_conf = <<-EOT
    events {}
    http {
      server {
        listen 80 default_server;
        server_name _;
        location / {
          root /usr/share/nginx/html;
          index index.html;
        }
      }
    }
  EOT

  index_html = <<-EOT
    <!DOCTYPE html>
    <html>
      <head>
        <title>Hello from ECS Fargate</title>
      </head>
      <body>
        <h1>Hello, world!</h1>
        <p>Served by nginx in ECS Fargate.</p>
      </body>
    </html>
  EOT
}

########################
# VPC & Networking
########################

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.tags, {
    Name = "${local.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = "${local.project_name}-igw"
  })
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_region.current.name == "us-east-1" ? "us-east-1${["a","b","c"][count.index]}" : null

  tags = merge(local.tags, {
    Name = "${local.project_name}-public-${count.index + 1}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.tags, {
    Name = "${local.project_name}-public-rt"
  })
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

########################
# Security Groups
########################

# ALB security group: allow HTTP/HTTPS from anywhere
resource "aws_security_group" "alb_sg" {
  name        = "${local.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.project_name}-alb-sg"
  })
}

# ECS task security group: allow traffic from ALB only
resource "aws_security_group" "ecs_sg" {
  name        = "${local.project_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "From ALB on HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {
    Name = "${local.project_name}-ecs-sg"
  })
}

########################
# ECS Cluster
########################

resource "aws_ecs_cluster" "this" {
  name = "${local.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = local.tags
}

########################
# IAM for ECS Task Execution
########################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.project_name}-task-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

########################
# Load Balancer & Target Group & Listener
########################

resource "aws_lb" "this" {
  name               = "${local.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]

  tags = merge(local.tags, {
    Name = "${local.project_name}-alb"
  })
}

resource "aws_lb_target_group" "this" {
  name        = "${local.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
  }

  tags = merge(local.tags, {
    Name = "${local.project_name}-tg"
  })
}

# HTTP listener -> redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener with ACM certificate
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

########################
# ECS Task Definition
########################

# Define a task definition with nginx using latest image from Docker Hub.
# We inject a simple index.html and nginx.conf as environment-embedded values.
resource "aws_ecs_task_definition" "nginx" {
  family                   = "${local.project_name}-nginx"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest"
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]
      command = [
        "/bin/sh",
        "-c",
        "echo '${replace(local.index_html, "'", "\\'")}' > /usr/share/nginx/html/index.html && " ..
        "echo '${replace(local.nginx_conf, "'", "\\'")}' > /etc/nginx/nginx.conf && " ..
        "nginx -g 'daemon off;'"
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.project_name}"
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "nginx"
        }
      }
    }
  ])

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  cpu    = var.task_cpu
  memory = var.task_memory

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.project_name}"
  retention_in_days = 7

  tags = local.tags
}

########################
# ECS Service
########################

resource "aws_ecs_service" "nginx" {
  name            = "${local.project_name}-svc"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.nginx.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = true
    subnets          = [for s in aws_subnet.public : s.id]
    security_groups  = [aws_security_group.ecs_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "nginx"
    container_port   = 80
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_lb_listener.https
  ]

  tags = local.tags
}
