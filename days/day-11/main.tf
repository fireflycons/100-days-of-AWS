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
  type        = string
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of devops, xfusion, datacenter, nautilus."
  }
}

locals {
  instance_name = "${var.infrastructure_prefix}-ec2"
  eni_name      = "${var.infrastructure_prefix}-eni"
}

data "aws_instances" "target" {
  filter {
    name   = "tag:Name"
    values = [local.instance_name]
  }
}

data "aws_network_interface" "target" {
  filter {
    name   = "tag:Name"
    values = [local.eni_name]
  }
}

resource "aws_network_interface_attachment" "attach_eni" {
  instance_id         = data.aws_instances.target.ids[0]
  network_interface_id = data.aws_network_interface.target.id
  device_index        = 1
}
