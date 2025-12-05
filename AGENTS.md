# Agents Guide: terraform-ecs-nomodule

This file gives focused, actionable instructions for AI coding agents working in this repository.
Keep edits minimal, explain assumptions in PRs, and always reference the main Terraform file(s) when changing infra.

## Big Picture
- Single-file Terraform deployment (`main.tf`) that provisions a VPC, public subnets, ALB (HTTP->HTTPS redirect), an ECS Fargate cluster, a single nginx task, CloudWatch logs, and IAM roles.
- `variables.tf` holds inputs (notably `acm_certificate_arn` which must be provided externally).
- `outputs.tf` exports `alb_dns_name`, `service_name`, and `cluster_name`.
- Design decision: no modules — the repo intentionally shows low-level resource composition.

## Primary Files to Inspect
- `main.tf` — authoritative source for architecture and resource wiring (networking, SGs, ALB, TG, ECS task/service).
- `variables.tf` — required inputs and defaults.
- `outputs.tf` — values automation or humans will read after apply.
- `.github/copilot-instructions.md` — higher-level guidance; consult before making broad changes.
- `CONTRIBUTING.md` — branch/commit conventions and Terraform best-practices for contributors.

## Editing & Change Guidance
- Follow branch naming from `CONTRIBUTING.md` (e.g. `feat/TERRAFORM-42_add-private-subnets`).
- Make the smallest change that accomplishes the task. Avoid reorganizing files or adding modules unless requested.
- When changing resource names or identifiers, consider downstream effects (state, resource recreation). Document rationale in the PR.
- Preserve `locals` usage and `local.tags` merging pattern for consistent resource tagging.

## Terraform Workflows & Commands
- Common local workflow:
  ```bash
  terraform init
  terraform fmt
  terraform validate
  terraform plan -out=change.plan
  terraform apply "change.plan"
  ```
- Run `terraform fmt` before committing.
- Use `terraform validate` and review `terraform plan` diffs carefully (this is infra — be conservative).

## Project-Specific Patterns & Gotchas
- Embedded multi-line config injection: `local.index_html` and `local.nginx_conf` are injected into the ECS container via a shell `command` that uses `replace()` to escape single quotes. Preserve this pattern when modifying those locals.
- Availability zone logic is hardcoded only for `us-east-1` — avoid changing that unless you're verifying cross-region behavior.
- `aws_ecs_service` uses `lifecycle { ignore_changes = [desired_count] }` — Terraform intentionally ignores desired_count drift (allows manual scaling). Do not remove unless explicitly required.
- ALB HTTPS listener requires a valid `acm_certificate_arn` passed in — `terraform apply` will fail without it.

## Security & IAM
- Follow least-privilege: the repo creates an ECS task execution role using Amazon-managed policy `AmazonECSTaskExecutionRolePolicy`.
- Security groups: ALB sg is open to 0.0.0.0/0 on 80/443; ECS sg only allows ingress from the ALB security group on port 80. Keep this pattern when refactoring.

## Testing, Validation & Deploy Safety
- Always run `terraform plan` and inspect changes. Look for resource replacements vs in-place updates.
- For destructive changes, recommend running in a non-production environment first.
- Use CloudWatch log group `/ecs/${local.project_name}` to verify container logs after deployment.

## When to Create New Files or Modules
- Default: keep everything in `main.tf` as the repo demonstrates a no-modules approach.
- Create modules only if the user asks explicitly to refactor — document the refactor plan and migration steps to preserve state.

## Commit & PR Notes (what to include)
- Reference the issue ID and branch in commit messages per `CONTRIBUTING.md`.
- In PR description, include:
  - What changed and why
  - Terraform plan summary (pasted or linked)
  - Any manual steps required to complete deployment
  - Impact/risk (replacements, downtime)

## Environment Notes
- The dev container runs Ubuntu 24.04.3 LTS (see workspace attachments). Use standard Terraform CLI installed in the environment.

## Cross-References
- See `.github/copilot-instructions.md` for higher-level architecture notes and common modifications.
- See `CONTRIBUTING.md` for branch naming and commit conventions.

## After Changes
- Run `terraform fmt` and `terraform validate` locally.
- Push branch, open PR, request review, and include a `terraform plan` excerpt in the PR.
