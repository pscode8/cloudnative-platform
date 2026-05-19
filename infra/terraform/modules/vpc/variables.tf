# ── VPC Module Variables ─────────────────────────────────────────
# These are the 'function parameters' of this module.
# Callers (environments/dev, environments/prod) pass in values.
# This is why modules exist — write once, call many times.

variable "project_name" {
  description = "Project name — used as prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name: dev, staging, prod"
  type        = string

  # Validation prevents typos from creating wrong environments
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. e.g. 10.0.0.0/16 gives 65,536 IPs"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to spread subnets across for high availability"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets (ALB lives here — internet-facing)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (EKS nodes, RDS live here — no direct internet)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
