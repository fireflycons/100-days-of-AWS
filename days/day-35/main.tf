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
  region = var.aws_region
}

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"
  type        = string

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

variable "rds_password" {
  type        = string
  description = "Password for RDS master user"
  sensitive   = true
}

variable "mysql_engine_version" {
  type        = string
  description = "MySQL engine version for RDS"
  default     = "8.4.5"
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

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_instance" "existing_ec2" {
  filter {
    name   = "tag:Name"
    values = ["nautilus-ec2"]
  }
}

data "aws_security_group" "existing_ec2_sg" {
  id = tolist(data.aws_instance.existing_ec2.vpc_security_group_ids)[0]
}

resource "aws_security_group_rule" "ec2_http_ingress" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.existing_ec2_sg.id
}

resource "aws_security_group_rule" "ec2_ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = data.aws_security_group.existing_ec2_sg.id
}

resource "aws_security_group" "rds_sg" {
  name   = "${var.infrastructure_prefix}-rds-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [data.aws_security_group.existing_ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.infrastructure_prefix}-rds-sg"
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.infrastructure_prefix}-rds-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "${var.infrastructure_prefix}-rds-subnet-group"
  }
}

resource "aws_db_instance" "rds" {
  identifier             = "${var.infrastructure_prefix}-rds"
  engine                 = "mysql"
  engine_version         = var.mysql_engine_version
  instance_class         = "db.t3.micro"
  username               = "${var.infrastructure_prefix}_admin"
  password               = var.rds_password
  allocated_storage      = 5
  storage_type           = "gp2"
  db_name                = "${var.infrastructure_prefix}_db"
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "${var.infrastructure_prefix}-rds"
  }
}

output "public_key" {
  value     = tls_private_key.ssh_key.public_key_openssh
}

output "db_host" {
  value = aws_db_instance.rds.address
}

output "db_name" {
  value = "${var.infrastructure_prefix}_db"
}

output "db_username" {
  value = aws_db_instance.rds.username
}

output "db_password" {
  value     = var.rds_password
}

output "db_port" {
  value = aws_db_instance.rds.port
}