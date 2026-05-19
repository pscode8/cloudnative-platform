# S3 bucket for Terraform remote state
# Run this ONCE manually before anything else
# terraform init && terraform apply

terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 bucket — stores all terraform state files
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.project_name}-terraform-state-${var.account_id}"

  lifecycle {
    prevent_destroy = true  # safety — never accidentally delete
  }

  tags = {
    Name        = "Terraform State"
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# Enable versioning — lets you recover old state files
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Block all public access — state files contain secrets
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encrypt state at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB table — prevents two people running terraform at same time
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "${var.project_name}-terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "Terraform State Lock"
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}
