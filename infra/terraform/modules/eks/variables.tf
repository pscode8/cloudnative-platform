# ── EKS Module Variables ─────────────────────────────────────────

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
}

variable "environment" {
  description = "Environment: dev, staging, prod"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version. Check AWS EKS release calendar before upgrading."
  type        = string
  default     = "1.30"
}

variable "vpc_id" {
  description = "VPC ID from the VPC module output"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes — nodes must be in private subnets"
  type        = list(string)
}

variable "bastion_sg_id" {
  description = "Security group ID of the bastion host allowed to access the EKS API"
  type        = string
}

variable "node_group_config" {
  description = "Node group sizing config"
  type = object({
    instance_types = list(string)
    desired_size   = number
    min_size       = number
    max_size       = number
    disk_size_gb   = number
  })
  # Dev defaults — cheap. Override in prod tfvars.
  default = {
    instance_types = ["t3.medium"] # 2 vCPU, 4GB RAM — enough for dev
    desired_size   = 2
    min_size       = 1
    max_size       = 4
    disk_size_gb   = 20
  }
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
