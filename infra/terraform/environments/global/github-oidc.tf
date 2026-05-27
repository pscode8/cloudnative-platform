# infra/terraform/environments/global/github-oidc.tf

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "cloudnative-terraform-state-483518901689"    # ← your existing state bucket
    key            = "global/github-oidc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true          
  }
}

provider "aws" {
  region = "us-east-2"
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  github_org   = "pscode8"       
  repo         = "cloudnative-platform"
  cluster_name = "cloudnative-dev"
  bastion_tag  = "bastion"

  tags = {
    Project   = "cloudnative-platform"
    ManagedBy = "terraform"
    Team      = "platform"
  }
}

output "oidc_provider_arn" {
  value = module.github_oidc.oidc_provider_arn
}

output "github_secrets_to_add" {
  description = "Paste these into GitHub → Settings → Environments → Secrets"
  value       = module.github_oidc.github_secrets
}
