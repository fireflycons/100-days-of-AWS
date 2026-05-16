terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}



###############################################################################
# Variables
###############################################################################

variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

###############################################################################
# Generate RSA Private Key
###############################################################################

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

###############################################################################
# Upload Public Key to AWS EC2
###############################################################################

resource "aws_key_pair" "ec2_keypair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.ec2_key.public_key_openssh
}

###############################################################################
# Outputs
###############################################################################

output "key_pair_name" {
  description = "Uploaded EC2 key pair name"
  value       = aws_key_pair.ec2_keypair.key_name
}

output "private_key_pem" {
  description = "Generated private key in PEM format"
  value       = tls_private_key.ec2_key.private_key_pem
  sensitive   = true
}
