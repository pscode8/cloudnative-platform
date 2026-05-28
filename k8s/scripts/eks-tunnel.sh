#!/usr/bin/env bash
# =============================================================================
# eks-tunnel.sh — Automated EKS SSM Tunnel + kubectl Setup
# Usage:  ./eks-tunnel.sh [start|stop|status]
# =============================================================================
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
REGION="us-east-2"
CLUSTER_NAME="cloudnative-dev"
BASTION_TAG="cloudnative-dev-bastion"
LOCAL_PORT="6443"
REMOTE_PORT="443"
PID_FILE="/tmp/eks-ssm-tunnel.pid"
LOG_FILE="/tmp/eks-ssm-tunnel.log"
MAX_WAIT=30
# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

check_deps() {
  for cmd in aws kubectl nc; do
    command -v "$cmd" &>/dev/null || error "'$cmd' is not installed or not in PATH."
  done
}

resolve_vars() {
  info "Resolving AWS variables..."

  BASTION_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=${BASTION_TAG}" "Name=instance-state-name,Values=running" \
    --region "$REGION" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)
  [[ "$BASTION_ID" == "None" || -z "$BASTION_ID" ]] && error "Bastion instance not found (tag:Name=${BASTION_TAG}, state=running)."
  success "Bastion:      $BASTION_ID"

  EKS_ENDPOINT=$(aws eks describe-cluster \
    --name "$CLUSTER_NAME" \
    --region "$REGION" \
    --query 'cluster.endpoint' \
    --output text | sed 's|https://||')
  [[ -z "$EKS_ENDPOINT" ]] && error "Could not resolve EKS endpoint for cluster '${CLUSTER_NAME}'."
  success "EKS endpoint: $EKS_ENDPOINT"

  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  CLUSTER_ARN="arn:aws:eks:${REGION}:${ACCOUNT_ID}:cluster/${CLUSTER_NAME}"
}

start_tunnel() {
  if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    kill "$OLD_PID" 2>/dev/null && info "Stopped stale tunnel (PID $OLD_PID)." || true
    rm -f "$PID_FILE"
  fi

  info "Starting SSM port-forward tunnel (background)..."
  aws ssm start-session \
    --target "$BASTION_ID" \
    --region "$REGION" \
    --document-name AWS-StartPortForwardingSessionToRemoteHost \
    --parameters "portNumber=${REMOTE_PORT},localPortNumber=${LOCAL_PORT},host=${EKS_ENDPOINT}" \
    >"$LOG_FILE" 2>&1 &

  TUNNEL_PID=$!
  echo "$TUNNEL_PID" > "$PID_FILE"
  success "Tunnel PID:   $TUNNEL_PID  (log → $LOG_FILE)"
}

wait_for_tunnel() {
  info "Waiting for tunnel on localhost:${LOCAL_PORT}..."
  for i in $(seq 1 $MAX_WAIT); do
    if nc -z 127.0.0.1 "$LOCAL_PORT" 2>/dev/null; then
      success "Tunnel is up! (${i}s)"
      return 0
    fi
    sleep 1
    echo -n "."
  done
  echo
  error "Tunnel did not open within ${MAX_WAIT}s. Check $LOG_FILE for details."
}

configure_kubectl() {
  info "Pulling cluster credentials (aws eks update-kubeconfig)..."
  aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
  success "kubeconfig updated."

  info "Redirecting kubectl → localhost:${LOCAL_PORT}..."
  kubectl config set-cluster "$CLUSTER_ARN" \
    --server="https://127.0.0.1:${LOCAL_PORT}" \
    --insecure-skip-tls-verify=true
  success "Cluster server overridden to https://127.0.0.1:${LOCAL_PORT}"
}

verify() {
  info "Running 'kubectl get nodes'..."
  if kubectl get nodes; then
    echo
    success "All done — cluster is reachable!"
  else
    error "kubectl get nodes failed. Check tunnel log: $LOG_FILE"
  fi
}

keepalive() {
  info "Starting tunnel keepalive (pings cluster every 15s)..."
  while true; do
    kubectl get nodes &>/dev/null || true
    sleep 15
  done &
  KEEPALIVE_PID=$!
  echo "$KEEPALIVE_PID" > /tmp/eks-keepalive.pid
  success "Keepalive PID: $KEEPALIVE_PID"
}

cmd_start() {
  check_deps
  resolve_vars
  start_tunnel
  wait_for_tunnel
  configure_kubectl
  verify
  keepalive
  echo
  info "To stop the tunnel later:  $0 stop"
  info "Tunnel log:                $LOG_FILE"
}

cmd_stop() {
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    kill "$PID" 2>/dev/null && success "Tunnel (PID $PID) stopped." || warn "Process $PID was already gone."
    rm -f "$PID_FILE"
  else
    warn "No PID file found — tunnel may not be running."
  fi

  if [[ -f /tmp/eks-keepalive.pid ]]; then
    KPID=$(cat /tmp/eks-keepalive.pid)
    kill "$KPID" 2>/dev/null && success "Keepalive (PID $KPID) stopped." || true
    rm -f /tmp/eks-keepalive.pid
  fi
}

cmd_status() {
  if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      success "Tunnel is running (PID $PID)."
      nc -z 127.0.0.1 "$LOCAL_PORT" 2>/dev/null \
        && success "Port $LOCAL_PORT is open." \
        || warn "Port $LOCAL_PORT is NOT yet open."
    else
      warn "PID file exists but process $PID is dead."
    fi
  else
    warn "Tunnel is not running."
  fi
}

cleanup() {
  echo
  warn "Interrupted — cleaning up tunnel..."
  cmd_stop
  exit 0
}
trap cleanup INT TERM

case "${1:-start}" in
  start)  cmd_start ;;
  stop)   cmd_stop  ;;
  status) cmd_status ;;
  *)      echo "Usage: $0 [start|stop|status]"; exit 1 ;;
esac