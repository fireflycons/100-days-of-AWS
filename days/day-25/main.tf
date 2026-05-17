# Configure the AWS Provider
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

# Variable with no default for the resource name prefix
variable "infrastructure_prefix" {
  type        = string
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

# Data source to find the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for the existing SNS topic
data "aws_sns_topic" "xfusion_topic" {
  name = "${var.infrastructure_prefix}-sns-topic"
}

# Create the EC2 Instance
resource "aws_instance" "xfusion_ec2" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "${var.infrastructure_prefix}-ec2"
  }
}

# Create the CloudWatch Alarm
resource "aws_cloudwatch_metric_alarm" "xfusion_alarm" {
  alarm_name          = "${var.infrastructure_prefix}-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300" # 5 minutes
  statistic           = "Average"
  threshold           = "90"
  alarm_description   = "This metric monitors ec2 cpu utilization"

  dimensions = {
    InstanceId = aws_instance.xfusion_ec2.id
  }

  alarm_actions = [data.aws_sns_topic.xfusion_topic.arn]
}
