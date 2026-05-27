#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# ecr-push-and-bootstrap.sh
# Builds all app images, pushes to ECR, then bootstraps the cluster
#
# Usage:
#   chmod +x k8s/scripts/ecr-push-and-bootstrap.sh
#   ./k8s/scripts/ecr-push-and-bootstrap.sh
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────
REGION="us-east-2"
ACCOUNT_ID="483518901689"
CLUSTER_NAME="cloudnative-dev"
BASTION_TAG="bastion"
LOCAL_PORT="6443"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_TAG="${1:-$(git rev-parse --short HEAD)}"

# ECR repo names
API_REPO="cloudnative/api"
FRONTEND_REPO="cloudnative/frontend"
WORKER_REPO="cloudnative/worker"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ── 1. ECR Login ──────────────────────────────────────────────────
ecr_login() {
  info "Logging into ECR..."
  aws ecr get-login-password --region "$REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY"
  success "ECR login successful"
}

# ── 2. Build and push a single image ─────────────────────────────
build_and_push() {
  local app=$1
  local repo=$2
  local dockerfile_path="apps/${app}/Dockerfile"

  if [[ ! -f "$dockerfile_path" ]]; then
    warn "No Dockerfile found for $app at $dockerfile_path — skipping"
    return
  fi

  info "Building $app..."
  local target_flag=""
   [[ "$app" == "api" ]] && target_flag="--target prod"

  docker build \
    $target_flag \
    -t "${REGISTRY}/${repo}:${IMAGE_TAG}" \
    -t "${REGISTRY}/${repo}:latest" \
    -f "$dockerfile_path" \
    "apps/${app}"

  info "Pushing $app:${IMAGE_TAG}..."
  docker push "${REGISTRY}/${repo}:${IMAGE_TAG}"
  docker push "${REGISTRY}/${repo}:latest"
  success "$app pushed → ${REGISTRY}/${repo}:${IMAGE_TAG}"
}

# ── 3. Start SSM tunnel ───────────────────────────────────────────
start_tunnel() {
  info "Starting SSM tunnel to EKS..."

  BASTION_ID=$(aws ec2 describe-instances \
    --filters \
      "Name=tag:Name,Values=${BASTION_TAG}" \
      "Name=instance-state-name,Values=running" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)
  [[ -z "$BASTION_ID" || "$BASTION_ID" == "None" ]] && error "Bastion not found"
  success "Bastion: $BASTION_ID"

  EKS_ENDPOINT=$(aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.endpoint' \
    --output text | sed 's|https://||')
  success "EKS endpoint: $EKS_ENDPOINT"

  aws ssm start-session \
    --target "$BASTION_ID" \
    --region "$REGION" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "portNumber=443,localPortNumber=${LOCAL_PORT},host=${EKS_ENDPOINT}" \
    > /tmp/ssm-tunnel.log 2>&1 &
  SSM_PID=$!
  echo "$SSM_PID" > /tmp/ssm-tunnel.pid

  info "Waiting for tunnel on localhost:${LOCAL_PORT}..."
  for i in $(seq 1 30); do
    if nc -z 127.0.0.1 "$LOCAL_PORT" 2>/dev/null; then
      success "Tunnel ready (${i}s)"
      break
    fi
    sleep 1
    echo -n "."
    if [[ $i -eq 30 ]]; then
      echo
      error "Tunnel did not open. Check /tmp/ssm-tunnel.log"
    fi
  done
  echo
}

# ── 4. Configure kubectl ──────────────────────────────────────────
configure_kubectl() {
  info "Configuring kubectl..."
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME" --quiet

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  CLUSTER_ARN="arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"

  kubectl config set-cluster "$CLUSTER_ARN" \
    --server="https://127.0.0.1:${LOCAL_PORT}" \
    --insecure-skip-tls-verify=true

  success "kubectl configured → $(kubectl config current-context)"
  kubectl get nodes
}

# ── 5. Run bootstrap ──────────────────────────────────────────────
run_bootstrap() {
  info "Running cluster bootstrap..."
  chmod +x k8s/bootstrap.sh
  bash k8s/bootstrap.sh
  success "Bootstrap complete!"
}

# ── Cleanup on exit ───────────────────────────────────────────────
cleanup() {
  if [[ -f /tmp/ssm-tunnel.pid ]]; then
    kill "$(cat /tmp/ssm-tunnel.pid)" 2>/dev/null || true
    rm -f /tmp/ssm-tunnel.pid
    info "SSM tunnel closed"
  fi
}
trap cleanup EXIT INT TERM

# ── Main ──────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " ECR Push + EKS Bootstrap"
echo " Image tag: $IMAGE_TAG"
echo "========================================"
echo ""

ecr_login
build_and_push "api"      "$API_REPO"
build_and_push "frontend" "$FRONTEND_REPO"
build_and_push "worker"   "$WORKER_REPO"

start_tunnel
configure_kubectl
run_bootstrap

echo ""
success "All done!"
echo "  Images pushed to ECR with tag: $IMAGE_TAG"
echo "  Cluster bootstrapped and ready"
echo "  ArgoCD UI: https://argocd.cloudnative.dev"