terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#########################################################
# VARIABLES
#########################################################

variable "infrastructure_prefix" {
  description = "Prefix used for all infrastructure resources"
  type        = string
}

variable "public_bucket_suffix" {
  description = "Numeric suffix for the public S3 bucket"
  type        = string
}

variable "private_bucket_suffix" {
  description = "Numeric suffix for the private S3 bucket"
  type        = string
}

#########################################################
# LOCALS
#########################################################

locals {
  public_bucket_name  = "${var.infrastructure_prefix}-public-${var.public_bucket_suffix}"
  private_bucket_name = "${var.infrastructure_prefix}-private-${var.private_bucket_suffix}"

  dynamodb_table_name = "${var.infrastructure_prefix}-S3CopyLogs"

  lambda_function_name = "${var.infrastructure_prefix}-copyfunction"
}

#########################################################
# S3 BUCKETS
#########################################################

resource "aws_s3_bucket" "public_bucket" {
  bucket = local.public_bucket_name
}

resource "aws_s3_bucket_public_access_block" "public_bucket_access_block" {
  bucket = aws_s3_bucket.public_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# resource "aws_s3_bucket_acl" "public_bucket_acl" {
#   depends_on = [
#     aws_s3_bucket_public_access_block.public_bucket_access_block
#   ]

#   bucket = aws_s3_bucket.public_bucket.id
#   acl    = "public-read"
# }

resource "aws_s3_bucket_policy" "public_bucket_policy" {
  bucket = aws_s3_bucket.public_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PublicReadGetObject"
        Effect = "Allow"

        Principal = "*"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${aws_s3_bucket.public_bucket.arn}/*"
        ]
      }
    ]
  })

  depends_on = [
    aws_s3_bucket_public_access_block.public_bucket_access_block
  ]
}

resource "aws_s3_bucket" "private_bucket" {
  bucket = local.private_bucket_name
}

resource "aws_s3_bucket_public_access_block" "private_bucket_access_block" {
  bucket = aws_s3_bucket.private_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#########################################################
# DYNAMODB TABLE
#########################################################

resource "aws_dynamodb_table" "copy_logs" {
  name         = local.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LogID"

  attribute {
    name = "LogID"
    type = "S"
  }
}

#########################################################
# PREPARE LAMBDA SOURCE
#########################################################

resource "null_resource" "prepare_lambda_source" {
  provisioner "local-exec" {
    command = <<EOT
cp /root/lambda-function.py /tmp/lambda-function.py

sed -i 's/REPLACE-WITH-YOUR-DYNAMODB-TABLE/${local.dynamodb_table_name}/g' /tmp/lambda-function.py
sed -i 's/REPLACE-WITH-YOUR-PRIVATE-BUCKET/${local.private_bucket_name}/g' /tmp/lambda-function.py
EOT
  }

  triggers = {
    always_run = timestamp()
  }
}

data "archive_file" "lambda_zip" {
  depends_on = [
    null_resource.prepare_lambda_source
  ]

  type        = "zip"
  source_file = "/tmp/lambda-function.py"
  output_path = "/tmp/lambda-function.zip"
}

#########################################################
# IAM ROLE + POLICIES
#########################################################

resource "aws_iam_role" "lambda_execution_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "lambda.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_policy" {
  name = "${var.infrastructure_prefix}-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]

        Resource = "arn:aws:logs:*:*:*"
      },

      {
        Effect = "Allow"

        Action = [
          "s3:GetObject"
        ]

        Resource = [
          "${aws_s3_bucket.public_bucket.arn}/*"
        ]
      },

      {
        Effect = "Allow"

        Action = [
          "s3:PutObject"
        ]

        Resource = [
          "${aws_s3_bucket.private_bucket.arn}/*"
        ]
      },

      {
        Effect = "Allow"

        Action = [
          "dynamodb:PutItem"
        ]

        Resource = aws_dynamodb_table.copy_logs.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

#########################################################
# LAMBDA FUNCTION
#########################################################

resource "aws_lambda_function" "copy_function" {
  depends_on = [
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]

  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda_execution_role.arn

  runtime = "python3.11"
  handler = "lambda-function.lambda_handler"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = 128
  timeout     = 10
}

#########################################################
# S3 EVENT NOTIFICATION
#########################################################

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy_function.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.public_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.public_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.copy_function.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_s3_invoke
  ]
}

#########################################################
# UPLOAD sample.zip TO PUBLIC BUCKET
#########################################################

resource "aws_s3_object" "sample_upload" {
  bucket = aws_s3_bucket.public_bucket.id
  key    = "sample.zip"
  source = "/root/sample.zip"

  etag = filemd5("/root/sample.zip")

  depends_on = [
    aws_s3_bucket_notification.bucket_notification
  ]
}