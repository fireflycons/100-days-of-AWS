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

variable "infra_prefix" {
  type        = string
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus etc.)"
}

variable "numeric_suffix" {
  type        = string
  description = "Numeric suffix for S3 bucket"
}

data "aws_instance" "existing_ec2" {
  filter {
    name   = "tag:Name"
    values = ["${var.infra_prefix}-ec2"]
  }
}

data "aws_security_group" "existing_ec2_sg" {
  id = tolist(data.aws_instance.existing_ec2.vpc_security_group_ids)[0]
}

resource "aws_security_group_rule" "ec2_ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.existing_ec2_sg.id
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = ".ssh/id_rsa"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content  = tls_private_key.ssh_key.public_key_openssh
  filename = ".ssh/id_rsa.pub"
}

resource "aws_s3_bucket" "s3" {
  bucket = "${var.infra_prefix}-s3-${var.numeric_suffix}"
}

resource "aws_iam_policy" "s3_policy" {
  name = "${var.infra_prefix}-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetObject"
        ]
        Resource = [
          aws_s3_bucket.s3.arn,
          "${aws_s3_bucket.s3.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "role" {
  name = "${var.infra_prefix}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.infra_prefix}-profile"
  role = aws_iam_role.role.name
}

resource "null_resource" "attach_role" {
  provisioner "local-exec" {
    command = "aws ec2 associate-iam-instance-profile --instance-id ${data.aws_instance.existing_ec2.id} --iam-instance-profile Name=${aws_iam_instance_profile.profile.name}"
  }

  depends_on = [aws_iam_instance_profile.profile]
}

output "public_key" {
  value     = tls_private_key.ssh_key.public_key_openssh
}

output "ec2_public_ip" {
  value = data.aws_instance.existing_ec2.public_ip
}