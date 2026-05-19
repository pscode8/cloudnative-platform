# ── Dev Environment Variable Values ──────────────────────────────
# File: infra/terraform/environments/dev/terraform.tfvars
#
# Explicit values for all variables — never rely on defaults in real runs.
# This file is safe to commit (no secrets — secrets live in Secrets Manager).
# The .env file holds secrets. This file holds config.

aws_region   = "us-east-2"
project_name = "cloudnative"
