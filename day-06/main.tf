terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion etc)"
  type        = string
}

# Get the latest Amazon Linux 2023 AMI from SSM
data "aws_ssm_parameter" "amazon_linux_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the default security group for the default VPC
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}

# Generate RSA private key
resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair
resource "aws_key_pair" "kp" {
  key_name   = "${var.name_prefix}-kp"
  public_key = tls_private_key.rsa.public_key_openssh
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.rsa.private_key_pem
  filename        = "${path.module}/${var.name_prefix}-kp.pem"
  file_permission = "0600"
}

# Create EC2 instance
resource "aws_instance" "ec2_instance" {
  ami           = data.aws_ssm_parameter.amazon_linux_ami.value
  instance_type = "t2.micro"
  key_name      = aws_key_pair.kp.key_name

  vpc_security_group_ids = [
    data.aws_security_group.default.id
  ]

  tags = {
    Name = "${var.name_prefix}-ec2"
  }
}

output "instance_id" {
  value = aws_instance.ec2_instance.id
}

output "public_ip" {
  value = aws_instance.ec2_instance.public_ip
}

output "key_pair_name" {
  value = aws_key_pair.kp.key_name
}