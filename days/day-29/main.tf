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

# Default VPC and public EC2 instance lookup
data "aws_vpc" "default" {
  default = true
}

data "aws_internet_gateway" "default_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_route_table" "default_main" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

data "aws_instances" "public_ec2" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-public-ec2"]
  }
}

data "aws_instance" "public_ec2_instance" {
  instance_id = data.aws_instances.public_ec2.ids[0]
}

resource "aws_security_group_rule" "public_ec2_ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = tolist(data.aws_instance.public_ec2_instance.vpc_security_group_ids)[0]
  description       = "Allow SSH from the internet to the public EC2 instance"
}

# Private VPC and subnet lookup
data "aws_vpc" "private" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-private-vpc"]
  }
}

data "aws_subnet" "private" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-private-subnet"]
  }
}

data "aws_route_table" "private_main" {
  vpc_id = data.aws_vpc.private.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

data "aws_instances" "private_ec2" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-private-ec2"]
  }
}

data "aws_instance" "private_ec2_instance" {
  instance_id = data.aws_instances.private_ec2.ids[0]
}

resource "aws_security_group_rule" "private_ec2_from_public_vpc" {
  type              = "ingress"
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = [data.aws_vpc.default.cidr_block]
  security_group_id = tolist(data.aws_instance.private_ec2_instance.vpc_security_group_ids)[0]
  description       = "Allow ICMP traffic from the public VPC to the private EC2 instance"
}

resource "aws_vpc_peering_connection" "vpc_peering" {
  peer_vpc_id = data.aws_vpc.private.id
  vpc_id      = data.aws_vpc.default.id
  auto_accept = true

  tags = {
    Name = "${var.infrastructure_prefix}-vpc-peering"
  }
}

resource "aws_route" "default_to_private" {
  route_table_id            = data.aws_route_table.default_main.id
  destination_cidr_block    = data.aws_vpc.private.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

resource "aws_route" "private_to_default" {
  route_table_id            = data.aws_route_table.private_main.id
  destination_cidr_block    = data.aws_vpc.default.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

output "vpc_peering_id" {
  value       = aws_vpc_peering_connection.vpc_peering.id
  description = "VPC peering connection ID"
}

output "default_vpc_id" {
  value       = data.aws_vpc.default.id
  description = "Default VPC ID"
}

output "private_vpc_id" {
  value       = data.aws_vpc.private.id
  description = "Private VPC ID"
}

output "private_subnet_id" {
  value       = data.aws_subnet.private.id
  description = "Private subnet ID"
}
