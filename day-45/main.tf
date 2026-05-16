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
  region = var.aws_region
}

#######################################
# Variables
#######################################

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "resource_prefix" {
  type        = string
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

#######################################
# Existing Infrastructure
#######################################

data "aws_vpc" "private_vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.resource_prefix}-priv-vpc"]
  }
}

data "aws_subnets" "existing_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.private_vpc.id]
  }
}

data "aws_subnet" "private_subnet" {
  filter {
    name   = "tag:Name"
    values = ["${var.resource_prefix}-priv-subnet"]
  }
}

data "aws_instance" "private_instance" {
  filter {
    name   = "tag:Name"
    values = ["${var.resource_prefix}-priv-ec2"]
  }
}

#######################################
# Internet Gateway
#######################################

resource "aws_internet_gateway" "igw" {
  vpc_id = data.aws_vpc.private_vpc.id

  tags = {
    Name = "${var.resource_prefix}-igw"
  }
}

#######################################
# Calculate Available /24 Subnet
#######################################

locals {
  vpc_cidr = data.aws_vpc.private_vpc.cidr_block

  existing_cidrs = [
    for subnet in data.aws_subnets.existing_subnets.ids :
    data.aws_subnet.existing[subnet].cidr_block
  ]

  candidate_subnets = [
    for i in range(1, 256) :
    cidrsubnet(local.vpc_cidr, 8, i)
  ]

  available_subnets = [
    for cidr in local.candidate_subnets :
    cidr if !contains(local.existing_cidrs, cidr)
  ]

  public_subnet_cidr = local.available_subnets[0]
}

data "aws_subnet" "existing" {
  for_each = toset(data.aws_subnets.existing_subnets.ids)

  id = each.value
}

#######################################
# Public Subnet
#######################################

resource "aws_subnet" "public_subnet" {
  vpc_id                  = data.aws_vpc.private_vpc.id
  cidr_block              = local.public_subnet_cidr
  availability_zone       = data.aws_subnet.private_subnet.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.resource_prefix}-pub-subnet"
  }
}

#######################################
# Public Route Table
#######################################

resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.private_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.resource_prefix}-pub-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#######################################
# Elastic IP for NAT Gateway
#######################################

resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "${var.resource_prefix}-nat-eip"
  }

  depends_on = [aws_internet_gateway.igw]
}

#######################################
# NAT Gateway
#######################################

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = {
    Name = "${var.resource_prefix}-natgw"
  }

  depends_on = [aws_internet_gateway.igw]
}

#######################################
# Private Route Table
#######################################

resource "aws_route_table" "private_rt" {
  vpc_id = data.aws_vpc.private_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "${var.resource_prefix}-priv-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = data.aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}