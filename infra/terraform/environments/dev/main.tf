# ── Dev Environment ───────────────────────────────────────────────
# This file orchestrates ALL infrastructure for dev.
# It calls each module like calling a function with arguments.
#
# TO CREATE DEV ENVIRONMENT:
#   terraform init
#   terraform plan -var-file=terraform.tfvars
#   terraform apply -var-file=terraform.tfvars
#
# TO DESTROY (save money when not using):
#   terraform destroy -var-file=terraform.tfvars
#   ⚠️ This deletes EVERYTHING including RDS data in dev

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

  # Tags applied to EVERY resource in this environment automatically
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = "devops-team"
    }
  }
}

# ── VPC ──────────────────────────────────────────────────────────
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = "dev"
  vpc_cidr     = "10.0.0.0/16"

  availability_zones   = ["us-east-2a", "us-east-2b"]
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ── ECR ──────────────────────────────────────────────────────────
# Create ECR repos BEFORE EKS — nodes need to pull images on start
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = "dev"
  repositories = ["api", "frontend", "worker"]
}

# ── EKS ──────────────────────────────────────────────────────────
module "eks" {
  source = "../../modules/eks"

  project_name       = var.project_name
  environment        = "dev"
  cluster_version    = "1.30"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Dev: small and cheap
  node_group_config = {
    instance_types = ["t3.small"]
    desired_size   = 1
    min_size       = 1
    max_size       = 2
    disk_size_gb   = 20
  }
}

# ── RDS ──────────────────────────────────────────────────────────
module "rds" {
  source = "../../modules/rds"

  project_name       = var.project_name
  environment        = "dev"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  vpc_cidr           = module.vpc.vpc_cidr

  # dev.t3.micro is FREE TIER ELIGIBLE — no cost for 750hrs/month
  instance_class        = "db.t3.micro"
  allocated_storage_gb  = 20
  backup_retention_days = 1 # 1 day for dev — save storage costs
}
