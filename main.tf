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
# Data
########################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# The rest of the Terraform configuration has been reorganized into
# smaller, focused files for readability and maintainability:
# - locals.tf
# - network.tf
# - security.tf
# - alb.tf
# - iam.tf
# - ecs.tf

# See README.md for the new file layout notes.
