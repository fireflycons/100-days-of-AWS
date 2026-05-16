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

variable "prefix" {
  description = "Resource name prefix (e.g. devops, xfusion etc.)"
  type        = string
}

data "aws_ebs_volume" "target" {
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-vol"]
  }
}

resource "aws_ebs_snapshot" "snapshot" {
  volume_id   = data.aws_ebs_volume.target.id
  description = "${var.prefix} Snapshot"

  tags = {
    Name = "${var.prefix}-vol-ss"
  }

  timeouts {
    create = "30m"
  }
}