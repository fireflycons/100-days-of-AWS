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
  description = "Resource name infrastructure_prefix (e.g. devops, xfusion etc.)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

data "aws_ebs_volume" "target" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-vol"]
  }
}

resource "aws_ebs_snapshot" "snapshot" {
  volume_id   = data.aws_ebs_volume.target.id
  description = "${var.infrastructure_prefix} Snapshot"

  tags = {
    Name = "${var.infrastructure_prefix}-vol-ss"
  }

  timeouts {
    create = "30m"
  }
}