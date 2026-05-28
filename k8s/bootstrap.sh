#!/usr/bin/env bash
# Usage:
#   chmod +x k8s/bootstrap.sh
#   ./k8s/bootstrap.sh
#
# Idempotent: helm upgrade --install = create if not exists, upgrade if exists.
# Safe to run multiple times.

set -euo pipefail  # Exit on error, undefined vars, pipe failures

CLUSTER_NAME="cloudnative-dev"
REGION="us-east-2"
ACCOUNT_ID="483518901689"

echo "Bootstrapping cluster: $CLUSTER_NAME"

# ── Connect kubectl ───────────────────────────────────────────────
echo "Connecting kubectl to EKS...via secure ssm, "
#aws eks update-kubeconfig   --name "$CLUSTER_NAME"   --region "$REGION"

kubectl get nodes  # Verify connection

# ── Create Namespaces ─────────────────────────────────────────────
echo "Creating namespaces..."
kubectl apply -f k8s/namespaces.yaml

# ── Add Helm Repos ────────────────────────────────────────────────
echo "Adding Helm repos..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add argo https://argoproj.github.io/argo-helm
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# ── 1. ArgoCD (PRIORITY INSTALL) ──────────────────────────────────
echo "Installing ArgoCD..."
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f gitops/argocd/install/argocd-values.yaml \
  --timeout 10m \
  --wait

# Apply ArgoCD project and app-of-apps
kubectl apply -f gitops/argocd/projects/cloudnative.yaml
kubectl apply -f gitops/argocd/app-of-apps.yaml

# Get initial ArgoCD admin password
echo ""
echo "ArgoCD initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo "------------------------------------------------------"

# ── 2. metrics-server (required for HPA) ────────────────────────────
echo "Installing metrics-server..."
helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  -f k8s/cluster-addons/metrics-server.yaml

# ── 3. cert-manager (required before ingress-nginx TLS) ─────────────
echo "Installing cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --wait  # Wait until cert-manager pods are Ready

# Apply ClusterIssuers
kubectl apply -f k8s/cluster-addons/cert-manager.yaml

# ── 4. ingress-nginx ─────────────────────────────────────────────────
echo "Installing ingress-nginx..."
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f k8s/cluster-addons/ingress-nginx.yaml \
  --wait

# Print the NLB DNS name — you need this for DNS records
echo ""
echo "NLB DNS name (create CNAME records pointing here):"
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
echo ""

echo "Bootstrap complete!"
echo "ArgoCD UI: https://argocd.cloudnative.dev"
echo "Run: kubectl get pods --all-namespaces"
