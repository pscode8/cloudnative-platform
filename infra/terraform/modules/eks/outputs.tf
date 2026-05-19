# ── EKS Module Outputs ───────────────────────────────────────────

output "cluster_name" {
  description = "EKS cluster name — used in aws eks update-kubeconfig"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint — kubectl connects here"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded CA certificate — kubectl uses to verify server"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true # Marked sensitive — won't show in plan output
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — needed to create IRSA roles for pods"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "OIDC provider URL — needed in IAM trust policies for IRSA"
  value       = aws_iam_openid_connect_provider.eks.url
}
