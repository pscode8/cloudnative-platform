# infra/terraform/modules/github-oidc/outputs.tf

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "role_arns" {
  description = "Map of environment → IAM role ARN"
  value = {
    for env, role in aws_iam_role.github_actions :
    env => role.arn
  }
}

output "github_secrets" {
  description = "Paste these into GitHub → Settings → Environments → Secrets"
  value = {
    AWS_ROLE_ARN_DEV     = aws_iam_role.github_actions["dev"].arn
    AWS_ROLE_ARN_STAGING = aws_iam_role.github_actions["staging"].arn
    AWS_ROLE_ARN_PROD    = aws_iam_role.github_actions["prod"].arn
  }
}