output "repository_urls" {
  description = "Map of repo name to full ECR URL"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of repo name to ARN — for IAM policies"
  value       = { for k, v in aws_ecr_repository.repos : k => v.arn }
}

output "registry_id" {
  description = "AWS account ID of the registry"
  value       = values(aws_ecr_repository.repos)[0].registry_id
}
