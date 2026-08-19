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

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of devops, xfusion, datacenter, nautilus."
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_security_group" "default_sg" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Allow the ALB (using the default security group) to receive HTTP from the internet
resource "aws_security_group_rule" "default_allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.default_sg.id
  description       = "Allow HTTP from internet to ALB (default SG)"
}

# Security group for the EC2 instance. Allow HTTP from the ALB (default SG).
resource "aws_security_group" "xfusion_sg" {
  name   = "${var.infrastructure_prefix}-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description       = "Allow HTTP from ALB (default SG)"
    from_port         = 80
    to_port           = 80
    protocol          = "tcp"
    security_groups   = [data.aws_security_group.default_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.infrastructure_prefix}-sg"
  }
}

# Application Load Balancer using the default security group
resource "aws_lb" "xfusion_alb" {
  name               = "${var.infrastructure_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [data.aws_security_group.default_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "${var.infrastructure_prefix}-alb"
  }
}

# Target group for the EC2 instance
resource "aws_lb_target_group" "xfusion_tg" {
  name     = "${var.infrastructure_prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  target_type = "instance"

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200-399"
  }

  tags = {
    Name = "${var.infrastructure_prefix}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.xfusion_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.xfusion_tg.arn
  }
}

# EC2 instance running nginx; placed in a subnet covered by the ALB (use first default subnet)
resource "aws_instance" "xfusion_ec2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = element(data.aws_subnets.default.ids, 0)
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.xfusion_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nginx
              systemctl enable --now nginx
              echo "<html><body><h1>xfusion nginx</h1></body></html>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "${var.infrastructure_prefix}-ec2"
  }
}

# Register the EC2 instance with the target group
resource "aws_lb_target_group_attachment" "xfusion_attach" {
  target_group_arn = aws_lb_target_group.xfusion_tg.arn
  target_id        = aws_instance.xfusion_ec2.id
  port             = 80
}

output "alb_dns_name" {
  description = "ALB DNS name to access the Nginx server"
  value       = aws_lb.xfusion_alb.dns_name
}
