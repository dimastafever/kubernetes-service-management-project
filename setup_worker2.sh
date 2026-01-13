#!/bin/bash

# Worker2 Kubernetes Node Setup Script
# This script sets up worker2 to join the Kubernetes cluster
# 
# Usage: sudo ./setup_worker2.sh <master-ip> <token> <ca-hash>
#
# Or run interactively without arguments

set -e

# Default configuration
MASTER_IP="${1:-192.168.1.74}"
TOKEN="${2:-}"
CA_HASH="${3:-sha256:5c2445614bb70c64f368369d931bae9afbfca7d418dab27eff81c114e4a16868}"
CRI_SOCKET="unix:///run/cri-dockerd.sock"

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
echo "Worker2 Kubernetes Node Setup"
echo "=========================================="
echo ""
echo "Master: ${MASTER_IP}:6443"
echo "CRI Socket: ${CRI_SOCKET}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check arguments
if [[ -z "$TOKEN" ]]; then
    log_warn "No token provided. Options:"
    echo ""
    echo "1. Get token from master:"
    echo "   ssh adminstd@${MASTER_IP} 'kubeadm token create --print-join-command'"
    echo ""
    echo "2. Run with arguments:"
    echo "   sudo $0 <master-ip> <token> <ca-hash>"
    echo ""
    echo "3. The script will attempt to use the current bootstrap config if available"
    echo ""
    
    # Check if we have a valid bootstrap config
    if [[ -f /etc/kubernetes/bootstrap-kubelet.conf ]]; then
        log_info "Found existing bootstrap config, attempting to join..."
    else
        log_error "No token provided and no bootstrap config found"
        exit 1
    fi
fi

# Step 1: Check prerequisites
echo ""
log_info "[STEP 1] Checking prerequisites..."

# Check kubelet
if ! command -v kubelet &> /dev/null; then
    log_error "kubelet not found. Install kubelet first."
    exit 1
fi
log_success "kubelet is installed"

# Check cri-dockerd
if ! sudo systemctl is-active --quiet cri-docker; then
    log_warn "cri-dockerd not running, starting..."
    sudo systemctl enable cri-docker
    sudo systemctl start cri-docker
    sleep 2
fi

if sudo systemctl is-active --quiet cri-docker; then
    log_success "cri-dockerd is running"
else
    log_error "cri-dockerd failed to start"
    exit 1
fi

# Check cri-dockerd socket
if [[ -S /run/cri-dockerd.sock ]]; then
    log_success "cri-dockerd socket exists"
else
    log_error "cri-dockerd socket not found"
    exit 1
fi

# Step 2: Stop existing kubelet
echo ""
log_info "[STEP 2] Stopping existing kubelet..."
sudo systemctl stop kubelet 2>/dev/null || true
sleep 2

# Step 3: Clean up old configs if new token provided
if [[ -n "$TOKEN" ]]; then
    echo ""
    log_info "[STEP 3] Cleaning up old configs..."
    sudo rm -f /etc/kubernetes/kubelet.conf 2>/dev/null || true
    sudo rm -f /etc/kubernetes/bootstrap-kubelet.conf 2>/dev/null || true
    log_success "Old configs removed"
fi

# Step 4: Run kubeadm join
echo ""
log_info "[STEP 4] Joining cluster..."

if [[ -n "$TOKEN" ]]; then
    # Join with provided token
    sudo kubeadm join ${MASTER_IP}:6443 \
        --token "${TOKEN}" \
        --discovery-token-ca-cert-hash "${CA_HASH}" \
        --cri-socket "${CRI_SOCKET}" \
        --ignore-preflight-errors=FileAvailable--etc-kubernetes-pki-ca.crt,FileAvailable--etc-kubernetes-kubelet.conf,FileAvailable--etc-kubernetes-bootstrap-kubelet.conf,SystemVerification
else
    # Try to use existing bootstrap config
    log_info "Using existing bootstrap config..."
    sudo systemctl start kubelet
fi

# Step 5: Wait for kubelet to start
echo ""
log_info "[STEP 5] Waiting for kubelet to start..."
sleep 10

# Step 6: Verify
echo ""
log_info "[STEP 6] Verification..."

# Check service
if sudo systemctl is-active --quiet kubelet; then
    log_success "kubelet is running"
else
    log_warn "kubelet may not be running properly"
    sudo systemctl status kubelet --no-pager | head -5
fi

# Health check
HEALTH=$(curl -sSL http://localhost:10248/healthz 2>&1 || echo "failed")
if [[ "$HEALTH" == "ok" ]]; then
    log_success "Health check passed"
else
    log_warn "Health check: $HEALTH"
fi

# Summary
echo ""
echo "=========================================="
echo "SETUP COMPLETE"
echo "=========================================="
echo ""
echo "Next steps:"
echo ""
echo "1. On MASTER (${MASTER_IP}), approve the CSR:"
echo "   kubectl get csr"
echo "   kubectl certificate approve <csr-name>"
echo ""
echo "2. Verify node status:"
echo "   kubectl get nodes"
echo ""
echo "3. If node doesn't appear, check worker2 logs:"
echo "   sudo journalctl -u kubelet --no-pager -n 50"
echo ""


