# terraform-ecs-nomodule
An ECS deployment not using Terraform AWS modules

## Terraform file layout

The Terraform configuration has been reorganized for readability. Key files:

- `main.tf`: Terraform `required_version`, provider and data blocks (entry point).
- `locals.tf`: Shared locals (`project_name`, `tags`, `nginx_conf`, `index_html`).
- `network.tf`: VPC, public subnets, route table, internet gateway and associations.
- `security.tf`: Security groups for ALB and ECS tasks.
- `alb.tf`: Application Load Balancer, target group and listeners (HTTP -> HTTPS redirect).
- `iam.tf`: IAM role and policy attachment for ECS task execution.
- `ecs.tf`: ECS cluster, task definition, CloudWatch log group and ECS service.

This split is a non-functional refactor to improve maintainability and navigation. No resource names were changed.
