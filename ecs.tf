# ecs.tf
# ECS resources: cluster, task definitions, services, and CloudWatch log groups.
# This file contains all container orchestration configuration.

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
        "echo '${replace(local.index_html, "'", "\\'")}' > /usr/share/nginx/html/index.html && echo '${replace(local.nginx_conf, "'", "\\'")}' > /etc/nginx/nginx.conf && nginx -g 'daemon off;'"
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

  tags = local.tags
}

########################
# CloudWatch Log Group
########################

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.project_name}"
  retention_in_days = 30

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
