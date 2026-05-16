terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

###############################################################################
# Provider
###############################################################################

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

variable "docker_build_context" {
  description = "Path to the Docker build context"
  type        = string
  default     = "/root/pyapp"
}

###############################################################################
# Locals
###############################################################################

locals {
  ecr_repo_name   = "${var.infrastructure_prefix}-ecr"
  ecs_cluster     = "${var.infrastructure_prefix}-cluster"
  ecs_service     = "${var.infrastructure_prefix}-service"
  task_definition = "${var.infrastructure_prefix}-taskdefinition"
}

###############################################################################
# Data Sources
###############################################################################

data "aws_vpcs" "all" {}

data "aws_vpc" "selected" {
  id = data.aws_vpcs.all.ids[0]
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

###############################################################################
# ECR Repository
###############################################################################

resource "aws_ecr_repository" "app" {
  name = local.ecr_repo_name

  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

###############################################################################
# Docker Build & Push
###############################################################################

resource "null_resource" "docker_build_push" {
  triggers = {
    image_repo = aws_ecr_repository.app.repository_url
    dockerfile = filesha256("${var.docker_build_context}/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<EOT
aws ecr get-login-password --region us-east-1 | docker login \
  --username AWS \
  --password-stdin ${aws_ecr_repository.app.repository_url}

docker build \
  -t ${local.ecr_repo_name}:latest \
  ${var.docker_build_context}

docker tag \
  ${local.ecr_repo_name}:latest \
  ${aws_ecr_repository.app.repository_url}:latest

docker push \
  ${aws_ecr_repository.app.repository_url}:latest
EOT
  }

  depends_on = [
    aws_ecr_repository.app
  ]
}

###############################################################################
# ECS Cluster
###############################################################################

resource "aws_ecs_cluster" "this" {
  name = local.ecs_cluster
}

###############################################################################
# IAM Role for ECS Task Execution
###############################################################################

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.infrastructure_prefix}-ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "ecs" {
  name        = "${var.infrastructure_prefix}-ecs-sg"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "HTTP ingress"
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
}

###############################################################################
# ECS Task Definition
###############################################################################

resource "aws_ecs_task_definition" "app" {
  family                   = local.task_definition
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "kke-container"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
    }
  ])

  depends_on = [
    null_resource.docker_build_push
  ]
}

###############################################################################
# ECS Service
###############################################################################

resource "aws_ecs_service" "app" {
  name            = local.ecs_service
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn

  desired_count = 1
  launch_type   = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution
  ]
}

###############################################################################
# Outputs
###############################################################################

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "security_group_id" {
  value = aws_security_group.ecs.id
}