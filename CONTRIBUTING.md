# Contributing to terraform-ecs-nomodule

## Branch Naming Convention

We follow **semantic branching** with the following format:

```
type/PROJ-XXX_dashed-description
```

### Format Breakdown
- **type**: Semantic commit type (see [Conventional Commits](https://www.conventionalcommits.org/))
  - `feat`: New feature or resource
  - `fix`: Bug fix or correction
  - `docs`: Documentation updates
  - `refactor`: Code restructuring without behavior change
  - `test`: Test additions or updates
  - `chore`: Maintenance, dependency updates, tooling
  - `perf`: Performance improvements

- **PROJ**: Project code (e.g., `TERRAFORM`, `INFRA`, `ECS`)
- **XXX**: Issue/ticket number
- **dashed-description**: Lowercase, hyphen-separated summary

### Examples
```
feat/TERRAFORM-42_add-private-subnets
fix/ECS-15_correct-security-group-rules
docs/INFRA-8_update-deployment-guide
refactor/TERRAFORM-23_consolidate-variables
chore/INFRA-101_upgrade-aws-provider-to-5-1
```

## Commit Message Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/) format:

```
type(scope): subject

body

footer
```

### Examples
```
feat(ecs-task): add support for custom docker images

- Add new variable `container_image` with default nginx:latest
- Update task definition to use parameterized image
- Allows users to override container image per deployment

Closes TERRAFORM-42
```

```
fix(security): restrict alb security group egress rules

- ALB no longer has unrestricted outbound access
- Only allows traffic to ECS security group on port 80
- Improves security posture for production deployments

Fixes ECS-15
```

## Terraform Coding Best Practices

### 1. Resource Naming & Tagging
- Use `local.project_name` as a consistent prefix for all resources
- Apply `local.tags` to every resource using `merge()` for additions:
  ```hcl
  tags = merge(local.tags, {
    Name = "${local.project_name}-resource-type"
  })
  ```
- This ensures consistent billing, ownership tracking, and resource identification

### 2. Variables & Defaults
- Provide sensible defaults for optional variables (VPC CIDR, task CPU/memory)
- Document all variables with `description` field
- Mark truly required values (like `acm_certificate_arn`) without defaults
- Group related variables logically in `variables.tf`

### 3. Locals for Configuration
- Use `locals` block to embed multi-line configs (nginx.conf, index.html, policies)
- Define computed values and naming conventions as locals
- Avoid hardcoding values that appear in multiple resources

### 4. Quote Escaping in Shell Commands
- When injecting multi-line configs into ECS task commands, use `replace()` to escape single quotes:
  ```hcl
  command = [
    "/bin/sh", "-c",
    "echo '${replace(local.config, "'", "\\'")}' > /etc/config && service start"
  ]
  ```
- Test the command locally before deploying to catch quote issues early

### 5. Security Groups
- Follow the principle of least privilege
- Create separate security groups for ALB and ECS tasks
- Use source security group references for inter-component communication:
  ```hcl
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # ALB → ECS only
  }
  ```
- Avoid overly permissive CIDR blocks (0.0.0.0/0) for internal communication

### 6. Load Balancer Configuration
- Always redirect HTTP to HTTPS in production
- Use target group health checks to validate container health
- Set health check thresholds appropriately:
  - Healthy/unhealthy threshold = 2 (default, reasonable for most cases)
  - Interval = 30s (standard, prevents false positives)
  - Timeout = 5s (should be less than interval)

### 7. ECS Task Definition
- Use `requires_compatibilities = ["FARGATE"]` for Fargate deployments
- Always set `network_mode = "awsvpc"` for Fargate
- Define `logConfiguration` with CloudWatch Logs for observability
- Use container `portMappings` to document exposed ports, even if ALB routes to them

### 8. IAM Roles & Policies
- Use AWS managed policies when available (e.g., `AmazonECSTaskExecutionRolePolicy`)
- Define `assume_role_policy` with service principals, not users
- Keep execution and task roles separate if task-specific permissions are needed

### 9. Lifecycle & Dependencies
- Use `lifecycle { ignore_changes = [desired_count] }` to allow manual scaling without Terraform drift
- Declare explicit dependencies with `depends_on` when resource creation order matters
- Example: ECS service must wait for load balancer listener to be created

### 10. Regional Considerations
- Avoid hardcoding availability zones unless required (current code does this for us-east-1 only)
- Use `data.aws_region.current.name` to reference current region dynamically
- Test multi-region deployments if that's a use case

### 11. Output Values
- Export key values needed post-deployment (ALB DNS, service name, cluster name)
- Include `description` for each output
- Make outputs discoverable for automation/monitoring tools

### 12. Testing & Validation
- Always run `terraform plan` and review the diff before applying
- Validate Terraform syntax with `terraform validate`
- Format code with `terraform fmt` before committing
- Test in a dev/staging environment first

## Pull Request Process

1. Create a branch following the naming convention
2. Make atomic commits with clear, semantic messages
3. Run `terraform fmt` to ensure consistent formatting
4. Include a PR description referencing the issue
5. Request review before merging to main
6. Delete the branch after merging

## Questions?

Refer to the [Copilot Instructions](/.github/copilot-instructions.md) for architecture and design patterns specific to this codebase.
