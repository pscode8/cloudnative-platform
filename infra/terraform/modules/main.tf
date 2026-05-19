# ── ECR Module ────────────────────────────────────────────────────
# Elastic Container Registry — private Docker registry in AWS.
# EKS nodes pull images from here. No DockerHub in production.
#
# WHY NOT DOCKERHUB IN PROD?
# - DockerHub rate limits (100 pulls/6h for free accounts)
# - DockerHub had an outage in 2021 that took down deployments globally
# - Private ECR: no rate limits, stays in your AWS network, encrypted
# - Security: you control who can push/pull

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "project_name" { type = string }
variable "environment" { type = string }
variable "repositories" {
  description = "List of repository names to create"
  type        = list(string)
  default     = ["api", "frontend", "worker"]
}
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repositories)

  name                 = "${var.project_name}/${each.value}"
  image_tag_mutability = "IMMUTABLE"
  # IMMUTABLE: once you push v1.2.3, that tag can never be overwritten.
  # Prevents: "but I pushed the fix!" when the tag already pointed elsewhere.
  # Production deployments always reference exact immutable digests.

  image_scanning_configuration {
    scan_on_push = true # Trivy-style scan on every push — catches CVEs early
  }

  encryption_configuration {
    encryption_type = "KMS" # Images encrypted with KMS, not default AES
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}/${each.value}"
    ManagedBy = "terraform"
  })
}

# ── Lifecycle Policy ─────────────────────────────────────────────
# Auto-deletes old untagged images. Without this, ECR fills up
# and you pay for storage of images nobody uses.
# Keeps last 10 tagged releases + deletes untagged after 1 day.
resource "aws_ecr_lifecycle_policy" "repos" {
  for_each   = aws_ecr_repository.repos
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Remove untagged images after 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only last 10 tagged releases"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })
}

output "repository_urls" {
  description = "Map of repository name to URL — used in CI to push images"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}
