# terraform-ecs-nomodule

An ECS deployment not using Terraform AWS modules.

## Overview

This Terraform project deploys a production-ready Nginx web server as a containerized application on AWS Elastic Container Service (ECS) using the Fargate serverless compute engine. The system provides a publicly accessible HTTPS endpoint fronted by an Application Load Balancer with automatic HTTP-to-HTTPS redirection.

## File Structure

The Terraform configuration is organized into logical files by domain:

| File | Description |
|------|-------------|
| `main.tf` | Entry point with terraform block and provider configuration |
| `variables.tf` | All input variable definitions with descriptions and defaults |
| `outputs.tf` | Exported resource identifiers (ALB DNS, service name, cluster name) |
| `locals.tf` | Shared local values: naming conventions, tags, embedded configs |
| `network.tf` | VPC, subnets, route tables, internet gateway, security groups |
| `iam.tf` | IAM roles and policy attachments for ECS task execution |
| `alb.tf` | Application Load Balancer, target groups, HTTP/HTTPS listeners |
| `ecs.tf` | ECS cluster, task definitions, services, CloudWatch log groups |

## Key Components

### Networking (`network.tf`)
- VPC with configurable CIDR block
- Public subnets across multiple availability zones
- Internet gateway and route tables for public internet access
- Security groups for ALB (HTTP/HTTPS from internet) and ECS tasks (traffic from ALB only)

### Load Balancing (`alb.tf`)
- Internet-facing Application Load Balancer
- HTTP listener with automatic redirect to HTTPS
- HTTPS listener with ACM certificate for SSL termination
- Target group with health checks for ECS tasks

### Container Orchestration (`ecs.tf`)
- ECS cluster with Fargate launch type
- Task definition with Nginx container and embedded configuration
- ECS service with load balancer integration
- CloudWatch log group for container logs

### Identity and Access (`iam.tf`)
- ECS task execution role for container image pulls and logging
- AWS managed policy attachment for ECS task execution

## Usage

1. Configure the required variables (see `variables.tf`)
2. Provide an ACM certificate ARN for HTTPS
3. Run `terraform init` to initialize the configuration
4. Run `terraform plan` to review changes
5. Run `terraform apply` to deploy the infrastructure

## Requirements

- Terraform >= 1.5.0
- AWS Provider ~> 5.0
- An existing ACM certificate in the target region
