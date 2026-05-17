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

#################################################
# Variables
#################################################

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

#################################################
# Data Sources
#################################################

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Default subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Existing EC2 instance
data "aws_instance" "ec2_instance" {
  filter {
    name   = "tag:Name"
    values = ["${var.infrastructure_prefix}-ec2"]
  }
}

#################################################
# Security Group for ALB
#################################################

resource "aws_security_group" "alb_sg" {
  name        = "${var.infrastructure_prefix}-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from public internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.infrastructure_prefix}-sg"
  }
}

#################################################
# Allow ALB to reach EC2 on port 80
#################################################

resource "aws_security_group_rule" "allow_alb_to_ec2" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = tolist(data.aws_instance.ec2_instance.vpc_security_group_ids)[0]
  source_security_group_id = aws_security_group.alb_sg.id
  description              = "Allow HTTP from ALB"
}

#################################################
# Target Group
#################################################

resource "aws_lb_target_group" "tg" {
  name     = "${var.infrastructure_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  tags = {
    Name = "${var.infrastructure_prefix}-tg"
  }
}

#################################################
# Attach EC2 Instance to Target Group
#################################################

resource "aws_lb_target_group_attachment" "ec2_attachment" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = data.aws_instance.ec2_instance.id
  port             = 80
}

#################################################
# Application Load Balancer
#################################################

resource "aws_lb" "alb" {
  name               = "${var.infrastructure_prefix}-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb_sg.id
  ]

  subnets = slice(data.aws_subnets.default.ids, 0, 2)

  tags = {
    Name = "${var.infrastructure_prefix}-alb"
  }
}

#################################################
# Listener
#################################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

#################################################
# Outputs
#################################################

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.tg.arn
}