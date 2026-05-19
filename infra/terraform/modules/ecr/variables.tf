variable "project_name" {
  description = "Project name — used as ECR namespace prefix (e.g. cloudnative/api)"
  type        = string
}

variable "environment" {
  description = "Environment: dev, staging, prod"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "repositories" {
  description = "List of repository names to create"
  type        = list(string)
  default     = ["api", "frontend", "worker"]
}

variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"
  validation {
    condition     = contains(["IMMUTABLE", "MUTABLE"], var.image_tag_mutability)
    error_message = "Must be IMMUTABLE or MUTABLE."
  }
}

variable "untagged_expiry_days" {
  type    = number
  default = 1
}

variable "tagged_keep_count" {
  type    = number
  default = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}
