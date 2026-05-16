terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }

    time = {
      source = "hashicorp/time"
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
  description = "Prefix used for naming infrastructure resources"
  type        = string
}

variable "python_runtime_version" {
  description = "Python runtime version for Lambda"
  type        = string
  default     = "3.11"
}

###############################################################################
# IAM Role
###############################################################################

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "time_sleep" "wait_for_iam" {
  # This is a workaround to ensure that the IAM role and policy attachment are fully propagated before we attempt to create the Lambda function.
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]

  create_duration = "20s"
}

###############################################################################
# Render CloudFormation YAML (fully interpolated)
###############################################################################

resource "local_file" "lambda_cloudformation_template" {
  filename = "${path.module}/${var.infrastructure_prefix}-lambda.yml"

  content = <<-YAML
AWSTemplateFormatVersion: '2010-09-09'
Description: CloudFormation stack to create a basic Lambda function

Resources:

  LambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: ${var.infrastructure_prefix}-lambda
      Runtime: python${var.python_runtime_version}
      Handler: index.lambda_handler
      Role: ${aws_iam_role.lambda_execution_role.arn}
      Timeout: 10
      Code:
        ZipFile: |
          def lambda_handler(event, context):
              return {
                  "statusCode": 200,
                  "body": "Welcome to KKE AWS Labs!"
              }

Outputs:

  LambdaFunctionName:
    Value: ${var.infrastructure_prefix}-lambda

  LambdaFunctionArn:
    Value: !GetAtt LambdaFunction.Arn
YAML
}

###############################################################################
# CloudFormation Stack
###############################################################################

resource "aws_cloudformation_stack" "lambda_stack" {
  name = "${var.infrastructure_prefix}-lambda-app"

  capabilities = ["CAPABILITY_NAMED_IAM"]

  template_body = local_file.lambda_cloudformation_template.content

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    time_sleep.wait_for_iam
  ]
}

###############################################################################
# Outputs
###############################################################################

output "lambda_role_arn" {
  value = aws_iam_role.lambda_execution_role.arn
}

output "cloudformation_stack_id" {
  value = aws_cloudformation_stack.lambda_stack.id
}