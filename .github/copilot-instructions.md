# Copilot Instructions: terraform-ecs-nomodule

## Project Overview
A **no-modules** Terraform deployment that provisions a complete ECS Fargate application with ALB, networking, and HTTPS on AWS. Contains 383 lines of single-file infrastructure-as-code showing the "building blocks" approach to AWS resources without abstraction.

## Architecture Pattern
**All resources in one main.tf file by design.** This is intentional to demonstrate low-level AWS resource composition:
- **Networking**: VPC → public subnets → internet gateway → public route table
- **Security**: Two security groups enforce ALB→ECS communication patterns
- **Load Balancing**: ALB with HTTP→HTTPS redirect, target group health checks
- **Compute**: ECS Fargate cluster with single nginx task
- **Logging**: CloudWatch log group for ECS task outputs

## Key Conventions

### File Organization
- `main.tf` (383 lines): All infrastructure resources, divided by section with `########################` comments
- `variables.tf`: Required ACM certificate ARN + optional defaults (VPC CIDR, task CPU/memory)
- `outputs.tf`: ALB DNS, service name, cluster name
- Provider version constraints: Terraform ≥1.5.0, AWS provider ~>5.0

### Locals Pattern
Critical for this codebase—heavily uses `locals` to avoid repetition:
```hcl
locals {
  project_name = var.project_name
  tags = { Project = local.project_name, Environment = var.environment, ManagedBy = "terraform" }
  nginx_conf = <<-EOT ...EOT   # Embedded config
  index_html = <<-EOT ...EOT   # Embedded HTML
}
```
All resources reference `local.tags` with merge() to add resource-specific naming.

### Task Container Configuration
The nginx task uses an inline shell command to inject configs:
```hcl
command = [
  "/bin/sh", "-c",
  "echo '${replace(local.index_html, "'", "\\'")}' > /usr/share/nginx/html/index.html && ..."
]
```
Careful with quote escaping when embedding multi-line configs—use `replace()` to escape single quotes.

### Availability Zone Hardcoding
Public subnets set AZ explicitly only for us-east-1:
```hcl
availability_zone = data.aws_region.current.name == "us-east-1" ? "us-east-1${["a", "b", "c"][count.index]}" : null
```
Other regions rely on AWS auto-assignment. This is a region-specific quirk, not a general pattern.

### Load Balancer Listener Routing
- **HTTP listener (port 80)**: Redirects to HTTPS (301)
- **HTTPS listener (port 443)**: Forwards to target group; requires pre-existing ACM certificate (required variable)
- **Health checks**: HTTP GET to "/" expecting 200-399 status, 30s interval, 2 healthy/unhealthy thresholds

## Common Modifications

**Change task image**: Update `image = "nginx:latest"` in container_definitions
**Adjust capacity**: Modify `var.task_cpu`, `var.task_memory`, or `desired_count` in ECS service
**Add private subnets**: Mirror public subnet pattern but set `map_public_ip_on_launch = false`, create separate NAT gateway and route table
**Multi-task deployment**: Increase service `desired_count` and adjust ALB minimum/maximum health percentages (currently 50/200)

## Dependencies & State
- **External**: Must provision ACM certificate separately—pass ARN via `acm_certificate_arn` variable
- **Lifecycle rule**: ECS service ignores changes to `desired_count` (enables manual scaling without Terraform drift)
- **IAM role**: Uses managed policy `AmazonECSTaskExecutionRolePolicy` (sufficient for basic logging)

## Testing & Deployment
No build or test commands—this is Terraform apply only:
```bash
terraform init
terraform plan
terraform apply
```
After deployment, access via ALB DNS name (output: `alb_dns_name`). nginx serves embedded index.html with "Hello, world!" message.

## Common Pitfalls
1. **Missing ACM certificate**: `terraform apply` fails if `acm_certificate_arn` not provided
2. **Quote escaping in commands**: Embedded configs must escape single quotes for shell interpolation
3. **Region assumptions**: AZ logic breaks outside us-east-1 (intentional limitation)
4. **Subnet count mismatch**: Ensure `length(var.public_subnet_cidrs)` matches intended availability zones
