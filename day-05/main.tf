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

variable "volume_name" {
  description = "Name of the EBS volume"
  type        = string
}

resource "aws_ebs_volume" "volume" {
  availability_zone = "us-east-1a"
  size              = 2
  type              = "gp3"

  tags = {
    Name = var.volume_name
  }
}
