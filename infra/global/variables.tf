variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in all resource names"
  type        = string
  default     = "cloudnative"
}

variable "account_id" {
  description = "AWS account ID — used to make bucket name unique"
  type        = string
}
