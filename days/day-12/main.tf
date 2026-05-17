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
data "aws_instance" "nautilus_ec2" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-ec2"]
  }
}

# Data source to get the existing EBS volume
data "aws_ebs_volume" "nautilus_volume" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-volume"]
  }
}

# Attach the volume to the instance
resource "aws_volume_attachment" "nautilus_attachment" {
  device_name = "/dev/sdb"
  volume_id   = data.aws_ebs_volume.nautilus_volume.id
  instance_id = data.aws_instance.nautilus_ec2.id
}
