# ── Dev Environment Outputs ──────────────────────────────────────
# After apply, run: terraform output
# These values tell you how to connect to everything.

output "eks_cluster_name" {
  description = "Run: aws eks update-kubeconfig --name <this_value>"
  value       = module.eks.cluster_name
}

output "ecr_repository_urls" {
  description = "Push images here: docker push <url>:tag"
  value       = module.ecr.repository_urls
}

output "db_secret_arn" {
  description = "Read DB creds: aws secretsmanager get-secret-value --secret-id <this>"
  value       = module.rds.secret_arn
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_gateway_ip" {
  description = "Whitelist this IP in any external services your app calls"
  value       = module.vpc.nat_gateway_ip
}
