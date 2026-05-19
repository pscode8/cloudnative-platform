# ── RDS Module Variables ─────────────────────────────────────────

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  description = "VPC ID — RDS security group attaches to this VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs — RDS lives here, no public access"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "VPC CIDR — used in security group to allow EKS nodes to connect"
  type        = string
}

variable "instance_class" {
  description = "RDS instance type. db.t3.micro = free tier. db.r6g.large = prod."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage_gb" {
  description = "Initial storage in GB. RDS autoscales up if needed."
  type        = number
  default     = 20
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "database_name" {
  description = "Name of the initial database to create"
  type        = string
  default     = "appdb"
}

variable "backup_retention_days" {
  description = "Days to keep automated backups. 0 = disabled. Min 7 for prod."
  type        = number
  default     = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
