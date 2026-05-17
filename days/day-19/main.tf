terraform {
  required_version = ">= 1.0.0"

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

variable "user_name" {
  description = "Existing IAM user name"
  type        = string
}

variable "policy_name" {
  description = "Existing IAM policy name"
  type        = string
}

data "aws_iam_user" "user" {
  user_name = var.user_name
}

data "aws_iam_policy" "policy" {
  name = var.policy_name
}

resource "aws_iam_user_policy_attachment" "attachment" {
  user       = data.aws_iam_user.user.user_name
  policy_arn = data.aws_iam_policy.policy.arn
}