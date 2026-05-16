terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = "us-east-1"
}

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

data "aws_vpc" "default" {
  filter {
    name   = "isDefault"
    values = ["true"]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.infrastructure_prefix}-rds-sg"
  description = "Allow MySQL access from the default VPC CIDR"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Allow MySQL from VPC CIDR"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.infrastructure_prefix}-rds-sg"
    Environment = "sandbox"
  }
}

resource "aws_db_subnet_group" "rds" {
  name       = "${var.infrastructure_prefix}-rds-subnet-group"
  subnet_ids = slice(data.aws_subnets.default.ids, 0, 2)
  description = "Subnet group for private ${var.infrastructure_prefix}-rds in two AZs"

  tags = {
    Name        = "${var.infrastructure_prefix}-rds-subnet-group"
    Environment = "sandbox"
  }
}

resource "aws_db_instance" "rds" {
  identifier            = "${var.infrastructure_prefix}-rds"
  allocated_storage     = 20
  max_allocated_storage = 50
  storage_type          = "gp2"
  engine                = "mysql"
  engine_version        = "8.4.8"
  instance_class        = "db.t3.micro"
  db_subnet_group_name  = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  username              = "admin"
  password              = "AdminPass"
  publicly_accessible   = false
  skip_final_snapshot   = true
  deletion_protection   = false
  apply_immediately     = true

  tags = {
    Name        = "${var.infrastructure_prefix}-rds"
    Environment = "sandbox"
  }
}
