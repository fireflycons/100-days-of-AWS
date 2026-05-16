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

############################################
# Variables
############################################

variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

############################################
# Generate SSH Key Pair
############################################

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key on aws-client host
resource "local_file" "private_key" {
  filename        = "/root/.ssh/id_rsa"
  content         = tls_private_key.ssh_key.private_key_pem
  file_permission = "0600"
}

# Save public key on aws-client host
resource "local_file" "public_key" {
  filename        = "/root/.ssh/id_rsa.pub"
  content         = tls_private_key.ssh_key.public_key_openssh
  file_permission = "0644"
}

############################################
# Security Group
############################################

resource "aws_security_group" "ssh_access" {
  name        = "${var.instance_name}-sg"
  description = "Allow SSH access"

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
}

############################################
# Get Latest Amazon Linux 2 AMI
############################################

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

############################################
# EC2 Instance
############################################

resource "aws_instance" "devops_ec2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ssh_access.id]

  tags = {
    Name = var.instance_name
  }

  user_data = <<-EOF
              #!/bin/bash
              mkdir -p /root/.ssh
              echo '${tls_private_key.ssh_key.public_key_openssh}' > /root/.ssh/authorized_keys
              chmod 700 /root/.ssh
              chmod 600 /root/.ssh/authorized_keys
              EOF
}

############################################
# Outputs
############################################

output "instance_public_ip" {
  value = aws_instance.devops_ec2.public_ip
}

output "ssh_command" {
  value = "ssh -i /root/.ssh/id_rsa root@${aws_instance.devops_ec2.public_ip}"
}