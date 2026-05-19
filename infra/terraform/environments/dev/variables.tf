# ── Dev Environment Variables ────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Project name used as prefix for all resource names"
  type        = string
  default     = "cloudnative"
}
