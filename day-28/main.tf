terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "infrastructure_prefix" {
  type        = string
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

resource "aws_ecr_repository" "private_repo" {
  name                 = "${var.infrastructure_prefix}-ecr"
  image_tag_mutability = "MUTABLE"

  tags = {
    Name = "${var.infrastructure_prefix}-ecr"
  }
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.private_repo.repository_url
  description = "URL of the ECR repository"
}

output "ecr_repository_arn" {
  value       = aws_ecr_repository.private_repo.arn
  description = "ARN of the ECR repository"
}
