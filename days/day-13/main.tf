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
  region = "us-east-1"
}

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of devops, xfusion, datacenter, nautilus."
  }
}

# Data source to get the existing EC2 instance
data "aws_instance" "ec2_instance" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-ec2"]
  }
}

# Create an AMI from the existing EC2 instance
resource "aws_ami_from_instance" "this" {
  name               = "${var.infrastructure_prefix}-ec2-ami"
  source_instance_id = data.aws_instance.ec2_instance.id
}
