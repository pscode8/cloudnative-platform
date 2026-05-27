# infra/terraform/modules/github-oidc/main.tf

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id        = data.aws_caller_identity.current.account_id
  region            = data.aws_region.current.name
  github_thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"
  environments      = toset(["dev", "staging", "prod"])
}

# 1. GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [local.github_thumbprint]

  tags = merge(var.tags, {
    Name = "github-actions-oidc"
  })
}

# 2. IAM Role per environment
resource "aws_iam_role" "github_actions" {
  for_each = local.environments

  name        = "github-actions-${each.key}"
  description = "Assumed by GitHub Actions for ${each.key} deployments via ${var.repo}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.repo}:environment:${each.key}"
          }
        }
      }
    ]
  })

  max_session_duration = 3600

  tags = merge(var.tags, {
    Name        = "github-actions-${each.key}"
    Environment = each.key
    ManagedBy   = "terraform"
  })
}

# 3. Deploy policy per environment
resource "aws_iam_policy" "deploy" {
  for_each = local.environments

  name        = "github-actions-deploy-${each.key}"
  description = "Least-privilege deploy policy for ${each.key} via GitHub Actions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSDescribe"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "arn:aws:eks:${local.region}:${local.account_id}:cluster/${var.cluster_name}"
      },
      {
        Sid    = "SSMTunnel"
        Effect = "Allow"
        Action = [
          "ssm:StartSession",
          "ssm:TerminateSession",
          "ssm:DescribeSessions",
          "ssm:GetConnectionStatus",
        ]
        Resource = [
          "arn:aws:ec2:${local.region}:${local.account_id}:instance/*",
          "arn:aws:ssm:${local.region}::document/AWS-StartPortForwardingSessionToRemoteHost",
        ]
        Condition = {
          StringEquals = {
            "ssm:resourceTag/Name" = var.bastion_tag
          }
        }
      },
      {
        Sid      = "EC2DescribeBastion"
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid    = "ECRPull"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = each.key == "prod" ? "Deny" : "Allow"
        Action = [
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = "arn:aws:ecr:${local.region}:${local.account_id}:repository/*"
      },
      {
        Sid      = "STSIdentity"
        Effect   = "Allow"
        Action   = ["sts:GetCallerIdentity"]
        Resource = "*"
      },
    ]
  })

  tags = merge(var.tags, {
    Environment = each.key
    ManagedBy   = "terraform"
  })
}

# 4. Attach policy to each role
resource "aws_iam_role_policy_attachment" "deploy" {
  for_each = local.environments

  role       = aws_iam_role.github_actions[each.key].name
  policy_arn = aws_iam_policy.deploy[each.key].arn
}