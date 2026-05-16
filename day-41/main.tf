terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "infrastructure_prefix" {
  type        = string
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  kms_key_alias = "${var.infrastructure_prefix}-KMS-Key"
}

resource "aws_kms_key" "this" {
  description = "KMS key for encryption/decryption"
  key_usage   = "ENCRYPT_DECRYPT"
}

resource "aws_kms_alias" "this" {
  name          = "alias/${local.kms_key_alias}"
  target_key_id = aws_kms_key.this.key_id
}

resource "null_resource" "encrypt_file" {
  depends_on = [aws_kms_alias.this]

  provisioner "local-exec" {
    command = <<-EOT
      aws kms encrypt \
        --region us-east-1 \
        --key-id alias/${local.kms_key_alias} \
        --plaintext fileb:///root/SensitiveData.txt \
        --output text \
        --query CiphertextBlob | base64 --decode > /root/EncryptedData.bin
    EOT
  }
}