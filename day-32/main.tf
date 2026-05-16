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

variable "infrastructure_prefix" {
  type        = string
  description = "Prefix used for resource names (e.g. devops, xfusion, datacenter, nautilus)"

  validation {
    condition     = contains(["devops", "xfusion", "datacenter", "nautilus"], var.infrastructure_prefix)
    error_message = "infrastructure_prefix must be one of: devops, xfusion, datacenter, nautilus"
  }
}

locals {
  source_db_identifier   = "${var.infrastructure_prefix}-rds"
  snapshot_identifier    = "${var.infrastructure_prefix}-snapshot"
  restored_db_identifier = "${var.infrastructure_prefix}-snapshot-restore"
}

#
# Lookup existing RDS instance
#
data "aws_db_instance" "source" {
  db_instance_identifier = local.source_db_identifier
}

#
# Wait for source DB to become available
#
resource "terraform_data" "wait_for_source_db" {
  triggers_replace = [
    data.aws_db_instance.source.db_instance_identifier,
    data.aws_db_instance.source.db_instance_status,
  ]

  provisioner "local-exec" {
    command = <<EOT
aws rds wait db-instance-available \
  --region us-east-1 \
  --db-instance-identifier ${data.aws_db_instance.source.id}
EOT
  }
}

#
# Create snapshot from existing DB
#
resource "aws_db_snapshot" "snapshot" {
  depends_on = [terraform_data.wait_for_source_db]

  db_instance_identifier = data.aws_db_instance.source.id
  db_snapshot_identifier = local.snapshot_identifier

  tags = {
    Name = local.snapshot_identifier
  }
}

#
# Restore snapshot into new DB instance
#
resource "aws_db_instance" "restored" {
  depends_on = [aws_db_snapshot.snapshot]

  identifier          = local.restored_db_identifier
  snapshot_identifier = aws_db_snapshot.snapshot.db_snapshot_arn
  instance_class      = "db.t3.micro"

  publicly_accessible      = false
  skip_final_snapshot      = true
  delete_automated_backups = true

  tags = {
    Name = local.restored_db_identifier
  }
}

output "snapshot_name" {
  value = aws_db_snapshot.snapshot.db_snapshot_identifier
}

output "restored_db_instance" {
  value = aws_db_instance.restored.id
}

output "restored_db_status" {
  value = aws_db_instance.restored.status
}