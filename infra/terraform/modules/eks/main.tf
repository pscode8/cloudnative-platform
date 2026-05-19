# ── EKS Module ────────────────────────────────────────────────────
# Elastic Kubernetes Service — AWS managed Kubernetes.
# AWS manages the control plane (API server, etcd, scheduler).
# You manage the worker nodes (EC2 instances that run your pods).
#
# SECURITY HIGHLIGHTS:
# - Private API endpoint: kubectl only works from inside VPC
# - IRSA: pods get IAM roles, not node-level credentials
# - Envelope encryption: Kubernetes secrets encrypted with KMS
# - Managed node groups: AWS handles node patching and replacement

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ── IAM Role for EKS Control Plane ──────────────────────────────
# The EKS service needs permissions to manage AWS resources on your behalf.
# This is the role the Kubernetes control plane assumes.
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = var.tags
}

# AWS managed policy — grants EKS control plane necessary permissions
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# ── EKS Cluster ──────────────────────────────────────────────────
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-${var.environment}"
  version  = var.cluster_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true   # kubectl works from inside VPC
    endpoint_public_access  = false  # SECURITY: API server not on internet
                                     # Attackers can't find or scan it
  }

  # Envelope encryption for Kubernetes secrets
  # Without this, secrets in etcd are base64 — not encrypted.
  # With this, they're wrapped with a KMS key you control.
  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  # Enable IRSA (IAM Roles for Service Accounts)
  # Pods can assume IAM roles directly via projected service account tokens.
  # No more: "give the node AdministratorAccess and hope for the best"
  # Instead: each pod gets exactly the permissions it needs, nothing more.
  # This is the AWS equivalent of zero-trust for workloads.
  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-eks"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── KMS Key for EKS Secret Encryption ───────────────────────────
# Customer-managed KMS key for encrypting Kubernetes secrets.
# If someone dumps etcd, secrets are encrypted with your key.
# You can revoke the key to instantly invalidate all secrets.
resource "aws_kms_key" "eks" {
  description             = "${var.project_name} ${var.environment} EKS secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true  # Rotate annually — security best practice

  tags = var.tags
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project_name}-${var.environment}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ── IAM Role for Node Group ──────────────────────────────────────
# Worker nodes need permissions to join the cluster, pull images, etc.
# Principle: give nodes ONLY what they need, nothing more.
resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.tags
}

# Minimum required policies for worker nodes
resource "aws_iam_role_policy_attachment" "eks_worker_node" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni" {
  # CNI plugin manages pod networking — needs VPC permissions
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  # Nodes need to pull images from your private ECR registry
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ── Node Group ───────────────────────────────────────────────────
# Managed node group = AWS handles: OS patching, node replacement,
# scaling, draining before termination. You just set the desired count.
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-${var.environment}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids  # Nodes in PRIVATE subnets

  instance_types = var.node_group_config.instance_types
  disk_size      = var.node_group_config.disk_size_gb

  scaling_config {
    desired_size = var.node_group_config.desired_size
    min_size     = var.node_group_config.min_size
    max_size     = var.node_group_config.max_size
  }

  # Rolling update — replaces nodes one at a time, zero downtime
  update_config {
    max_unavailable = 1
  }

  # Node labels — used by Kubernetes to schedule pods on right nodes
  labels = {
    Environment = var.environment
    NodeGroup   = "main"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node,
    aws_iam_role_policy_attachment.eks_cni,
    aws_iam_role_policy_attachment.ecr_read,
  ]

  tags = merge(var.tags, {
    Name        = "${var.project_name}-${var.environment}-node"
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── IRSA: OIDC Provider ──────────────────────────────────────────
# Enables IAM Roles for Service Accounts (IRSA).
# EKS exposes an OIDC endpoint. AWS IAM trusts this endpoint.
# Pods present a signed token → AWS verifies with OIDC → grants role.
# No credentials stored on nodes. Tokens auto-rotate every 24h.
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = var.tags
}
