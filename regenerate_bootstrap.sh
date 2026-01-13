#!/bin/bash

# Regenerate bootstrap-kubelet.conf on worker2
# This script recreates the bootstrap config using the current token
#
# Usage: sudo ./regenerate_bootstrap.sh

set -e

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

echo "=========================================="
echo "Regenerate Bootstrap Config"
echo "=========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Step 1: Stop kubelet
log_info "[STEP 1] Stopping kubelet..."
sudo systemctl stop kubelet
sleep 2

# Step 2: Check if we have a valid token
log_info "[STEP 2] Checking for existing bootstrap config..."

if [[ -f /etc/kubernetes/bootstrap-kubelet.conf ]]; then
    # Extract token from existing config
    TOKEN=$(sudo grep -oP '"token": "\K[^"]+' /etc/kubernetes/bootstrap-kubelet.conf 2>/dev/null | head -1)
    
    if [[ -n "$TOKEN" ]]; then
        log_info "Found token in existing config: ${TOKEN:0:10}..."
    else
        log_warn "No token found in existing config"
        log_error "Please provide a fresh token manually"
        exit 1
    fi
else
    log_warn "No existing bootstrap config found"
    log_error "Please run apply_fresh_token.sh with a valid token"
    exit 1
fi

# Step 3: Get CA certificate
log_info "[STEP 3] Getting CA certificate..."
CA_DATA=$(sudo cat /etc/kubernetes/pki/ca.crt 2>/dev/null | base64 -w0)

if [[ -z "$CA_DATA" ]]; then
    log_error "CA certificate not found"
    exit 1
fi

# Step 4: Recreate bootstrap config
log_info "[STEP 4] Regenerating bootstrap config..."
sudo rm -f /etc/kubernetes/bootstrap-kubelet.conf

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
log_success "Bootstrap config regenerated"

# Step 5: Restart kubelet
log_info "[STEP 5] Starting kubelet..."
sudo systemctl daemon-reload
sudo systemctl start kubelet
sleep 5

# Step 6: Verify
echo ""
log_info "[STEP 6] Verification..."

if sudo systemctl is-active --quiet kubelet; then
    log_success "kubelet is active"
else
    log_warn "kubelet status:"
    sudo systemctl status kubelet --no-pager | head -5
fi

HEALTH=$(curl -sSL http://localhost:10248/healthz 2>&1 || echo "failed")
echo "Health check: $HEALTH"

if [[ "$HEALTH" == "ok" ]]; then
    log_success "Health check passed"
fi

echo ""
echo "=========================================="
echo "DONE"
echo "=========================================="
echo ""
echo "Wait ~30 seconds, then on master check:"
echo "  kubectl get csr"
echo "  kubectl certificate approve <csr-name>"
echo "  kubectl get nodes"
echo ""


