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

#########################################################
# Variables
#########################################################

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

variable "bucket_suffix" {
  description = "Numeric suffix for S3 bucket name"
  type        = string

  validation {
    condition     = can(tonumber(var.bucket_suffix)) && tonumber(var.bucket_suffix) > 0
    error_message = "bucket_suffix must be a positive integer"
  }
}

#########################################################
# Existing Infrastructure Lookups
#########################################################

data "aws_vpc" "private_vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-priv-vpc"]
  }
}

data "aws_subnet" "private_subnet" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-priv-subnet"]
  }
}

data "aws_route_table" "private_rt" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-priv-rt"]
  }
}

data "aws_instance" "private_ec2" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-priv-ec2"]
  }
}

data "aws_key_pair" "nautilus_key" {
  key_name = "${var.infrastructure_prefix}-key"
}

#########################################################
# Public VPC
#########################################################

resource "aws_vpc" "public_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.infrastructure_prefix}-pub-vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.public_vpc.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.infrastructure_prefix}-pub-subnet"
  }
}

resource "aws_internet_gateway" "public_igw" {
  vpc_id = aws_vpc.public_vpc.id

  tags = {
    Name = "${var.infrastructure_prefix}-pub-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.public_vpc.id

  tags = {
    Name = "${var.infrastructure_prefix}-pub-rt"
  }
}

resource "aws_route" "internet_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public_igw.id
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

#########################################################
# Security Group
#########################################################

resource "aws_security_group" "public_sg" {
  name        = "${var.infrastructure_prefix}-pub-sg"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.public_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.infrastructure_prefix}-pub-sg"
  }
}

#########################################################
# S3 Bucket
#########################################################

resource "aws_s3_bucket" "logs_bucket" {
  bucket = "${var.infrastructure_prefix}-s3-logs-${var.bucket_suffix}"

  tags = {
    Name = "${var.infrastructure_prefix}-s3-logs-${var.bucket_suffix}"
  }
}

resource "aws_s3_bucket_public_access_block" "logs_bucket_block" {
  bucket = aws_s3_bucket.logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#########################################################
# IAM Role for EC2
#########################################################

resource "aws_iam_role" "s3_role" {
  name = "${var.infrastructure_prefix}-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "s3_put_policy" {
  name = "${var.infrastructure_prefix}-s3-put-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.logs_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.s3_role.name
  policy_arn = aws_iam_policy.s3_put_policy.arn
}

resource "aws_iam_instance_profile" "s3_profile" {
  name = "${var.infrastructure_prefix}-s3-profile"
  role = aws_iam_role.s3_role.name
}

#########################################################
# Public EC2 Instance
#########################################################

resource "aws_instance" "public_ec2" {
  ami                    = data.aws_instance.private_ec2.ami
  instance_type          = data.aws_instance.private_ec2.instance_type
  subnet_id              = aws_subnet.public_subnet.id
  key_name               = "${var.infrastructure_prefix}-key"
  vpc_security_group_ids = [aws_security_group.public_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.s3_profile.name

  associate_public_ip_address = true

  user_data = <<-EOF
            #!/bin/bash
            set -e

            apt update
            apt install -y awscli

            mkdir -p /home/ubuntu/.ssh

            # Write private key locally on public instance
            cat > /home/ubuntu/.ssh/${var.infrastructure_prefix}-key.pem <<'KEY'
            ${file("/root/.ssh/${var.infrastructure_prefix}-key.pem")}
            KEY

            chmod 600 /home/ubuntu/.ssh/${var.infrastructure_prefix}-key.pem
            chown -R ubuntu:ubuntu /home/ubuntu/.ssh

            PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

            #############################################
            # Cron on PUBLIC instance
            #############################################
            { crontab -l -u ubuntu 2>/dev/null || true; echo "* * * * * aws s3 cp /home/ubuntu/boots.log s3://${aws_s3_bucket.logs_bucket.bucket}/${var.infrastructure_prefix}-priv-vpc/boot/boots.log"; } | crontab -u ubuntu -

            #############################################
            # Copy key to PRIVATE instance
            #############################################
            scp -o StrictHostKeyChecking=no \
                -i /home/ubuntu/.ssh/${var.infrastructure_prefix}-key.pem \
                /home/ubuntu/.ssh/${var.infrastructure_prefix}-key.pem \
                ubuntu@${data.aws_instance.private_ec2.private_ip}:/home/ubuntu/.ssh/

            ssh -o StrictHostKeyChecking=no \
                -i /home/ubuntu/.ssh/${var.infrastructure_prefix}-key.pem \
                ubuntu@${data.aws_instance.private_ec2.private_ip} << REMOTE

            chmod 600 /home/ubuntu/.ssh/${var.infrastructure_prefix}-key.pem

            #############################################
            # Cron on PRIVATE instance
            #############################################
            (crontab -l 2>/dev/null; echo "* * * * * scp -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/${var.infrastructure_prefix}-key.pem /var/log/boots.log ubuntu@$PUBLIC_IP:/home/ubuntu/boots.log") | crontab -

            REMOTE

            EOF
  tags = {
    Name = "${var.infrastructure_prefix}-pub-ec2"
  }
}

#########################################################
# VPC Peering
#########################################################

resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id      = data.aws_vpc.private_vpc.id
  peer_vpc_id = aws_vpc.public_vpc.id
  auto_accept = true

  tags = {
    Name = "${var.infrastructure_prefix}-vpc-peering"
  }
}

#########################################################
# Routing Between VPCs
#########################################################

resource "aws_route" "private_to_public" {
  route_table_id            = data.aws_route_table.private_rt.id
  destination_cidr_block    = aws_vpc.public_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

resource "aws_route" "public_to_private" {
  route_table_id            = aws_route_table.public_rt.id
  destination_cidr_block    = data.aws_vpc.private_vpc.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

#########################################################
# Outputs
#########################################################

output "public_ec2_ssh_command" {
  description = "SSH command for accessing the public EC2 instance"

  value = "ssh -i /root/.ssh/${var.infrastructure_prefix}-key.pem ubuntu@${aws_instance.public_ec2.public_ip}"
}

output "private_ec2_ssh_command_from_public" {
  description = "SSH command to access the private EC2 instance from the public EC2 instance"

  value = "ssh -i /home/ubuntu/.ssh/${var.infrastructure_prefix}-key.pem ubuntu@${data.aws_instance.private_ec2.private_ip}"
}