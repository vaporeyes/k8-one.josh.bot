# ABOUTME: Terraform and provider version constraints.
# ABOUTME: Pins AWS provider and sets default resource tags.

terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "k8-one-blog"
      ManagedBy  = "terraform"
      Repository = "vaporeyes/k8-one.josh.bot"
    }
  }
}
