# infra/terraform/modules/github-oidc/variables.tf

variable "github_org" {
  description = "GitHub organization or username (e.g. 'my-org')"
  type        = string
}

variable "repo" {
  description = "GitHub repo name without org prefix (e.g. 'cloudnative-platform')"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used to scope EKS IAM permissions"
  type        = string
}

variable "bastion_tag" {
  description = "Value of the EC2 Name tag on the bastion host"
  type        = string
  default     = "bastion"
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
