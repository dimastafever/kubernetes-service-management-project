#!/bin/bash

# Apply fresh token to worker2
# This script updates the bootstrap config with a new token
#
# Usage: sudo ./apply_fresh_token.sh <token>
#
# Example:
#   # Get token from master:
#   ssh adminstd@192.168.1.74 'kubeadm token create --print-join-command'
#
#   # Apply on worker2:
#   sudo ./apply_fresh_token.sh 5l8vvq.m55kqdgws0btwy36

set -e

TOKEN="${1}"
MASTER_IP="192.168.1.74"
API_PORT="6443"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=========================================="
echo "Apply Fresh Token to Worker2"
echo "=========================================="
echo ""

# Check arguments
if [[ -z "$TOKEN" ]]; then
    log_error "No token provided"
    echo ""
    echo "Usage: sudo $0 <token>"
    echo ""
    echo "To get a fresh token, on master run:"
    echo "  kubeadm token create --print-join-command"
    echo ""
    exit 1
fi

echo "Token: ${TOKEN:0:10}..."
echo "Master: ${MASTER_IP}:${API_PORT}"
echo ""

# Step 1: Stop kubelet
log_info "[STEP 1] Stopping kubelet..."
sudo systemctl stop kubelet
sleep 2
log_success "Kubelet stopped"

# Step 2: Get CA certificate data
log_info "[STEP 2] Getting CA certificate..."
CA_DATA=$(sudo cat /etc/kubernetes/pki/ca.crt 2>/dev/null | base64 -w0)

if [[ -z "$CA_DATA" ]]; then
    log_error "CA certificate not found at /etc/kubernetes/pki/ca.crt"
    exit 1
fi
log_success "CA certificate loaded"

# Step 3: Create bootstrap config
log_info "[STEP 3] Creating bootstrap-kubelet.conf..."
sudo mkdir -p /etc/kubernetes

sudo bash -c "cat > /etc/kubernetes/bootstrap-kubelet.conf << EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CA_DATA}
    server: https://${MASTER_IP}:${API_PORT}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: tls-bootstrap-token-user
  name: tls-bootstrap-token-user@kubernetes
current-context: tls-bootstrap-token-user@kubernetes
kind: Config
preferences: {}
users:
- name: tls-bootstrap-token-user
  user:
    token: ${TOKEN}
EOF"
log_success "Bootstrap config created"

# Step 4: Restart kubelet
log_info "[STEP 4] Restarting kubelet..."
sudo systemctl daemon-reload
sudo systemctl start kubelet
sleep 5

# Step 5: Verify
echo ""
log_info "[STEP 5] Verification..."
echo ""

# Service status
if sudo systemctl is-active --quiet kubelet; then
    log_success "kubelet is active"
else
    log_warn "kubelet status:"
    sudo systemctl status kubelet --no-pager | head -5
fi

# Health check
HEALTH=$(curl -sSL http://localhost:10248/healthz 2>&1 || echo "failed")
echo "Health check: $HEALTH"
if [[ "$HEALTH" == "ok" ]]; then
    log_success "Health check passed"
fi

# Summary
echo ""
echo "=========================================="
echo "TOKEN APPLIED"
echo "=========================================="
echo ""
echo "Next steps on MASTER (${MASTER_IP}):"
echo ""
echo "1. Check for CSR:"
echo "   kubectl get csr"
echo ""
echo "2. Approve CSR:"
echo "   kubectl certificate approve <csr-name>"
echo ""
echo "3. Verify:"
echo "   kubectl get nodes"
echo ""


