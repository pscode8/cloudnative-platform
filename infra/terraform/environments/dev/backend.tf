# ── Dev Environment Remote State ─────────────────────────────────
# IMPORTANT: Each environment has its own state key.
# dev/terraform.tfstate and prod/terraform.tfstate are separate files.
# Destroying dev NEVER touches prod state.

terraform {
  backend "s3" {
    bucket         = "cloudnative-terraform-state-483518901689"
    key            = "environments/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloudnative-terraform-lock"
    encrypt        = true
  }
}
