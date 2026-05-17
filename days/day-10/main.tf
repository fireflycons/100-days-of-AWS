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
  eip_name      = "${var.infrastructure_prefix}-ec2-eip"
}

data "aws_instances" "target" {
  filter {
    name   = "tag:Name"
    values = [local.instance_name]
  }
}

data "aws_eips" "target" {
  filter {
    name   = "tag:Name"
    values = [local.eip_name]
  }
}

resource "aws_eip_association" "nautilus_ec2" {
  instance_id   = data.aws_instances.target.ids[0]
  allocation_id = data.aws_eips.target.allocation_ids[0]
}
