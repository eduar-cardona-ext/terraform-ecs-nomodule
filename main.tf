# main.tf
# High-level orchestration: terraform block, provider configuration.
# This file serves as the entry point for the Terraform configuration.
# Resource definitions are organized in dedicated files by domain.

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
