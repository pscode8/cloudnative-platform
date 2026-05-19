# ── Remote Backend Configuration ─────────────────────────────────
# Stores terraform.tfstate in S3 instead of locally.
# DynamoDB prevents two engineers running apply simultaneously
# (distributed lock — like a mutex for infrastructure).
#
# SECURITY: State files contain plaintext secrets (DB passwords, keys).
# This bucket has encryption + versioning + no public access.
# Lesson from Capital One 2019: exposed state = full breach.

terraform {
  backend "s3" {
    bucket         = "cloudnative-terraform-state-483518901689"
    key            = "global/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "cloudnative-terraform-lock"
    encrypt        = true  # AES-256 encryption at rest
  }
}
