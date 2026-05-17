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

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
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
  key_name   = "${var.infrastructure_prefix}-kp"
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
