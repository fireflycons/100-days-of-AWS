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

###############################################################################
# Variables
###############################################################################

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus etc.)"
  type        = string
}

###############################################################################
# Data Sources
###############################################################################

data "aws_eks_cluster_versions" "latest" {
  version_status = "STANDARD_SUPPORT"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "az_a" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1a"]
  }
}

data "aws_subnets" "az_b" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1b"]
  }
}

data "aws_subnets" "az_c" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["us-east-1c"]
  }
}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = data.aws_vpc.default.id
}

###############################################################################
# Locals
###############################################################################

locals {
  eks_version = data.aws_eks_cluster_versions.latest.cluster_versions[0].cluster_version
  eks_subnet_ids = [
    sort(data.aws_subnets.az_a.ids)[0],
    sort(data.aws_subnets.az_b.ids)[0],
    sort(data.aws_subnets.az_c.ids)[0],
  ]
}
###############################################################################
# IAM Role for EKS Cluster
###############################################################################

resource "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

###############################################################################
# EKS Cluster
###############################################################################

resource "aws_eks_cluster" "this" {
  name     = "${var.infrastructure_prefix}-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = local.eks_version

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids = local.eks_subnet_ids

    security_group_ids = [
      data.aws_security_group.default.id
    ]

    endpoint_private_access = true
    endpoint_public_access  = false
  }

  kubernetes_network_config {
    ip_family = "ipv4"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

###############################################################################
# Outputs
###############################################################################

output "eks_cluster_name" {
  value = aws_eks_cluster.this.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "eks_cluster_version" {
  value = aws_eks_cluster.this.version
}