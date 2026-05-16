terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "infrastructure_prefix" {
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus etc.)"
  type = string
}

resource "aws_dynamodb_table" "tasks" {
  name         = "${var.infrastructure_prefix}-tasks"
  billing_mode = "PROVISIONED"

  hash_key = "taskId"

  attribute {
    name = "taskId"
    type = "S"
  }

  read_capacity  = 5
  write_capacity = 5
}

resource "null_resource" "task_1" {
  depends_on = [aws_dynamodb_table.tasks]

  provisioner "local-exec" {
    command = <<EOT
aws dynamodb put-item \
  --region us-east-1 \
  --table-name ${aws_dynamodb_table.tasks.name} \
  --item '{"taskId": {"S": "1"}, "description": {"S": "Learn DynamoDB"}, "status": {"S": "completed"}}'
EOT
  }
}

resource "null_resource" "task_2" {
  depends_on = [aws_dynamodb_table.tasks]

  provisioner "local-exec" {
    command = <<EOT
aws dynamodb put-item \
  --region us-east-1 \
  --table-name ${aws_dynamodb_table.tasks.name} \
  --item '{"taskId": {"S": "2"}, "description": {"S": "Build To-Do App"}, "status": {"S": "in-progress"}}'
EOT
  }
}