# network.tf
# Networking resources: VPC, subnets, route tables, internet gateway, and security groups.
# This file contains all network infrastructure required for the ECS deployment.

########################
# Data Sources
########################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

########################
# Local Values
########################

locals {
  # Default ALB ingress to VPC CIDR if not explicitly specified (private access only)
  alb_ingress_cidrs = var.allowed_alb_ingress_cidrs != null ? var.allowed_alb_ingress_cidrs : [var.vpc_cidr]
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
  availability_zone       = data.aws_region.current.name == "us-east-1" ? "us-east-1${["a", "b", "c"][count.index]}" : null

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

# ALB security group: allow HTTP/HTTPS from specified CIDR ranges (defaults to VPC CIDR for private access)
resource "aws_security_group" "alb_sg" {
  name        = "${local.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTP from allowed CIDRs"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.alb_ingress_cidrs
  }

  ingress {
    description = "HTTPS from allowed CIDRs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = local.alb_ingress_cidrs
  }

  egress {
    description = "To ECS tasks on HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
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
    description     = "From ALB on HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "HTTPS to internet for AWS APIs and image pulls"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS to VPC resolver"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.tags, {
    Name = "${local.project_name}-ecs-sg"
  })
}
