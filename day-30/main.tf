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
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus etc.)"
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

#################################################################################
# EC2 Instance Connect IP Ranges
# curl and jq must be installed on the machine running Terraform for this to work
#################################################################################

data "external" "ec2_instance_connect_ranges" {
  program = [
    "bash",
    "-c",
    <<-EOF
      curl -s https://ip-ranges.amazonaws.com/ip-ranges.json \
      | jq -r --arg REGION "${var.aws_region}" '
        [
          .prefixes[]
          | select(.region == $REGION and .service == "EC2_INSTANCE_CONNECT")
          | .ip_prefix
        ] | { cidrs: join(",") }
      '
    EOF
  ]
}

locals {
  ec2_instance_connect_cidrs = split(
    ",",
    data.external.ec2_instance_connect_ranges.result.cidrs
  )
}

#######################################
# NAT Security Group
#######################################

resource "aws_security_group" "nat_sg" {
  name        = "${var.resource_prefix}-nat-sg"
  description = "Allow traffic from VPC for NAT"
  vpc_id      = data.aws_vpc.private_vpc.id

  ingress {
    description = "Allow all traffic from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.private_vpc.cidr_block]
  }

  ingress {
    description = "SSH from EC2 Instance Connect"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ec2_instance_connect_cidrs
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.resource_prefix}-nat-sg"
  }
}

#######################################
# Latest Amazon Linux 2023 AMI
#######################################

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#######################################
# NAT Instance
#######################################

resource "aws_instance" "nat_instance" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nat_sg.id]

  source_dest_check = false

  user_data = <<-EOF
    #!/bin/bash
    # Enable IP forwarding
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    sysctl -p

    # Install iptables
    yum install -y iptables-services

    # Discover interface used to talk to the outside world
    # In AL2023 it can be different every time!
    IFACE=$(ip -o route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')

    # Configure iptables for NAT
    iptables -t nat -A POSTROUTING -o "$IFACE" -j MASQUERADE
    iptables -A FORWARD -i "$IFACE" -o "$IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i "$IFACE" -o "$IFACE" -j ACCEPT

    # Save iptables rules
    iptables-save > /etc/sysconfig/iptables

    systemctl enable iptables
    systemctl restart iptables
  EOF

  tags = {
    Name = "${var.resource_prefix}-nat-instance"
  }

  depends_on = [aws_internet_gateway.igw]
}

#######################################
# Private Route Table Update
#######################################

data "aws_route_table" "private_rt" {
  subnet_id = data.aws_subnet.private_subnet.id
}

resource "aws_route" "private_nat_route" {
  route_table_id         = data.aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance.primary_network_interface_id
}