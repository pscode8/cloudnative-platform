set -euo pipefail

REGION="us-east-2"
ACCOUNT_ID="483518901689"
CLUSTER_NAME="cloudnative-dev"
BASTION_TAG="cloudnative-dev-bastion"
LOCAL_PORT="6443"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_TAG="${1:-$(git rev-parse --short HEAD)}"

API_REPO="cloudnative/api"
FRONTEND_REPO="cloudnative/frontend"
WORKER_REPO="cloudnative/worker"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

ecr_login() {
  info "Logging into ECR..."
  aws ecr get-login-password --region "$REGION" \
    | docker login --username AWS --password-stdin "$REGISTRY"
  success "ECR login successful"
}

build_and_push() {
  local app=$1
  local repo=$2
  local dockerfile_path="apps/${app}/Dockerfile"

  if [[ ! -f "$dockerfile_path" ]]; then
    warn "No Dockerfile found for $app — skipping"
    return
  fi

  local target_flag=""
  [[ "$app" == "api" ]] && target_flag="--target prod"

  info "Building $app..."
  docker build \
    $target_flag \
    -t "${REGISTRY}/${repo}:${IMAGE_TAG}" \
    -f "$dockerfile_path" \
    "apps/${app}"

  # Skip push if tag already exists in ECR (immutable tags)
  if aws ecr describe-images \
      --repository-name "$repo" \
      --image-ids imageTag="$IMAGE_TAG" \
      --region "$REGION" \
      &>/dev/null; then
    warn "$app:${IMAGE_TAG} already exists in ECR — skipping push"
  else
    info "Pushing $app:${IMAGE_TAG}..."
    docker push "${REGISTRY}/${repo}:${IMAGE_TAG}"
    success "$app pushed → ${REGISTRY}/${repo}:${IMAGE_TAG}"
  fi
}

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
    2>/tmp/ssm-tunnel.log &
  SSM_PID=$!
  echo "$SSM_PID" > /tmp/ssm-tunnel.pid

  info "Waiting for tunnel on localhost:${LOCAL_PORT}..."
  for i in $(seq 1 30); do
    if nc -z 127.0.0.1 "$LOCAL_PORT" 2>/dev/null; then
      success "Tunnel ready (${i}s)"
      return
    fi
    sleep 1
    echo -n "."
  done
  echo
  error "Tunnel did not open. Check /tmp/ssm-tunnel.log"
}

configure_kubectl() {
  info "Configuring kubectl..."
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  CLUSTER_ARN="arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"

  kubectl config set-cluster "$CLUSTER_ARN" \
    --server="https://127.0.0.1:${LOCAL_PORT}" \
    --insecure-skip-tls-verify=true

  success "kubectl configured"
  kubectl get nodes
}

run_bootstrap() {
  info "Running cluster bootstrap..."
  chmod +x k8s/bootstrap.sh
  bash k8s/bootstrap.sh
  success "Bootstrap complete!"
}

cleanup() {
  if [[ -f /tmp/ssm-tunnel.pid ]]; then
    kill "$(cat /tmp/ssm-tunnel.pid)" 2>/dev/null || true
    rm -f /tmp/ssm-tunnel.pid
    info "SSM tunnel closed"
  fi
}
trap cleanup EXIT INT TERM

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
SCRIPT

chmod +x ~/projects/cloudnative-platform/k8s/scripts/ecr-push-and-bootstrap.sh
