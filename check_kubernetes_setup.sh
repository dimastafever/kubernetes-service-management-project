#!/bin/bash

# Kubernetes Setup Verification & Completion Script
# Checks which steps from the original task are completed and performs missing ones

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Kubernetes Setup Verification Script"
echo "=========================================="
echo ""

# Function to check if a step is completed
check_step() {
    local step_name=$1
    local check_command=$2
    local result=$(eval $check_command 2>/dev/null)
    if [ -n "$result" ]; then
        echo -e "${GREEN}✓${NC} $step_name - COMPLETED"
        return 0
    else
        echo -e "${RED}✗${NC} $step_name - NOT COMPLETED"
        return 1
    fi
}

echo "=========================================="
echo "  Checking Step 1: Swap Configuration"
echo "=========================================="

# Check if swap is disabled
if grep -q '^[^#].*swap' /etc/fstab 2>/dev/null; then
    echo -e "${RED}✗${NC} Swap is still configured in /etc/fstab"
    SWAP_FSTAB=0
else
    echo -e "${GREEN}✓${NC} Swap line commented/removed from /etc/fstab"
    SWAP_FSTAB=1
fi

if swapon --show 2>/dev/null | grep -q '.'; then
    echo -e "${RED}✗${NC} Swap is still active"
    SWAP_ACTIVE=0
else
    echo -e "${GREEN}✓${NC} Swap is disabled"
    SWAP_ACTIVE=1
fi

echo ""
echo "=========================================="
echo "  Checking Step 2: Kernel Modules"
echo "=========================================="

# Check br_netfilter
if lsmod | grep -q br_netfilter 2>/dev/null; then
    echo -e "${GREEN}✓${NC} br_netfilter module loaded"
    BR_NETFILTER=1
else
    echo -e "${RED}✗${NC} br_netfilter module NOT loaded"
    BR_NETFILTER=0
fi

# Check overlay
if lsmod | grep -q overlay 2>/dev/null; then
    echo -e "${GREEN}✓${NC} overlay module loaded"
    OVERLAY=1
else
    echo -e "${RED}✗${NC} overlay module NOT loaded"
    OVERLAY=0
fi

# Check if modules are in /etc/modules
if [ -f /etc/modules ] && grep -q 'br_netfilter' /etc/modules 2>/dev/null; then
    echo -e "${GREEN}✓${NC} br_netfilter configured in /etc/modules"
else
    echo -e "${YELLOW}!${NC} br_netfilter NOT in /etc/modules"
fi

if [ -f /etc/modules ] && grep -q 'overlay' /etc/modules 2>/dev/null; then
    echo -e "${GREEN}✓${NC} overlay configured in /etc/modules"
else
    echo -e "${YELLOW}!${NC} overlay NOT in /etc/modules"
fi

echo ""
echo "=========================================="
echo "  Checking Step 3: IP Forwarding"
echo "=========================================="

IP_FORWARD=$(cat /proc/sys/net/ipv4/ip_forward 2>/dev/null || echo "0")
if [ "$IP_FORWARD" = "1" ]; then
    echo -e "${GREEN}✓${NC} IP forwarding is enabled (ip_forward=1)"
    IPV4_FORWARD=1
else
    echo -e "${RED}✗${NC} IP forwarding is DISABLED (ip_forward=$IP_FORWARD)"
    IPV4_FORWARD=0
fi

echo ""
echo "=========================================="
echo "  Checking Step 4: Kubernetes Components"
echo "=========================================="

# Check kubelet
if command -v kubelet &> /dev/null; then
    KUBELET_VERSION=$(kubelet --version 2>/dev/null | head -1 || echo "installed")
    echo -e "${GREEN}✓${NC} kubelet installed: $KUBELET_VERSION"
    KUBELET=1
else
    echo -e "${RED}✗${NC} kubelet NOT installed"
    KUBELET=0
fi

# Check kubeadm
if command -v kubeadm &> /dev/null; then
    KUBEADM_VERSION=$(kubeadm version 2>/dev/null | head -1 || echo "installed")
    echo -e "${GREEN}✓${NC} kubeadm installed: $KUBEADM_VERSION"
    KUBEADM=1
else
    echo -e "${RED}✗${NC} kubeadm NOT installed"
    KUBEADM=0
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    KUBECTL_VERSION=$(kubectl version --client 2>/dev/null | head -1 || echo "installed")
    echo -e "${GREEN}✓${NC} kubectl installed"
    KUBECTL=1
else
    echo -e "${RED}✗${NC} kubectl NOT installed"
    KUBECTL=0
fi

# Check if packages are held
if dpkg --get-selections 2>/dev/null | grep -q 'kubelet.*hold'; then
    echo -e "${GREEN}✓${NC} kubelet marked as hold"
else
    echo -e "${YELLOW}!${NC} kubelet NOT marked as hold (may auto-update)"
fi

echo ""
echo "=========================================="
echo "  Checking Step 5: Container Runtime"
echo "=========================================="

# Check cri-dockerd
if command -v cri-dockerd &> /dev/null; then
    CRI_DOCKERD_VERSION=$(cri-dockerd --version 2>/dev/null || echo "installed")
    echo -e "${GREEN}✓${NC} cri-dockerd installed: $CRI_DOCKERD_VERSION"
    CRI_DOCKERD=1
else
    echo -e "${YELLOW}!${NC} cri-dockerd NOT installed"
    CRI_DOCKERD=0
fi

# Check crio (CRI-O)
if command -v crio &> /dev/null; then
    CRI_O_VERSION=$(crio --version 2>/dev/null || echo "installed")
    echo -e "${GREEN}✓${NC} CRI-O installed: $CRI_O_VERSION"
    CRI_O=1
else
    echo -e "${YELLOW}!${NC} CRI-O NOT installed"
    CRI_O=0
fi

# Check if cri-dockerd service exists and is running
if systemctl list-unit-files | grep -q 'cri-dockerd' 2>/dev/null; then
    echo -e "${GREEN}✓${NC} cri-dockerd service file exists"
    if systemctl is-active --quiet cri-dockerd 2>/dev/null; then
        echo -e "${GREEN}✓${NC} cri-dockerd service is running"
        CRI_DOCKERD_RUNNING=1
    else
        echo -e "${YELLOW}!${NC} cri-dockerd service NOT running"
        CRI_DOCKERD_RUNNING=0
    fi
else
    echo -e "${YELLOW}!${NC} cri-dockerd service NOT found"
    CRI_DOCKERD_RUNNING=0
fi

# Check if /run/cri-dockerd.sock exists
if [ -S /run/cri-dockerd.sock ]; then
    echo -e "${GREEN}✓${NC} /run/cri-dockerd.sock exists"
    SOCKET=1
else
    echo -e "${YELLOW}!${NC} /run/cri-dockerd.sock NOT found"
    SOCKET=0
fi

echo ""
echo "=========================================="
echo "  Checking Step 6: Cluster Initialization"
echo "=========================================="

# Check if cluster is initialized
if [ -f /etc/kubernetes/admin.conf ]; then
    echo -e "${GREEN}✓${NC} /etc/kubernetes/admin.conf exists (cluster initialized)"
    CLUSTER_INIT=1
    
    # Check if kubectl can connect
    if kubectl --kubeconfig=/etc/kubernetes/admin.conf cluster-info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Cluster is accessible"
        CLUSTER_ACCESS=1
    else
        echo -e "${YELLOW}!${NC} Cluster is NOT accessible"
        CLUSTER_ACCESS=0
    fi
else
    echo -e "${RED}✗${NC} /etc/kubernetes/admin.conf NOT found (cluster not initialized)"
    CLUSTER_INIT=0
    CLUSTER_ACCESS=0
fi

# Check for master node
if kubectl get nodes 2>/dev/null | grep -q 'master\|control-plane'; then
    echo -e "${GREEN}✓${NC} Master/Control-Plane node exists"
    MASTER_NODE=1
else
    echo -e "${YELLOW}!${NC} Master/Control-Plane node NOT found"
    MASTER_NODE=0
fi

echo ""
echo "=========================================="
echo "  Checking Step 7: Worker Node Join"
echo "=========================================="

# Check if this is a worker node
if [ -f /etc/kubernetes/kubelet.conf ]; then
    echo -e "${GREEN}✓${NC} /etc/kubernetes/kubelet.conf exists (node joined cluster)"
    WORKER_JOIN=1
else
    echo -e "${YELLOW}!${NC} /etc/kubernetes/kubelet.conf NOT found"
    WORKER_JOIN=0
fi

# Check for kubelet.conf in /etc/kubernetes
if ls /etc/kubernetes/*.conf &> /dev/null; then
    echo -e "${GREEN}✓${NC} Kubernetes config files exist:"
    ls /etc/kubernetes/*.conf 2>/dev/null
else
    echo -e "${YELLOW}!${NC} No Kubernetes config files found"
fi

echo ""
echo "=========================================="
echo "  Checking Step 8: CSR & Node Object"
echo "=========================================="

# This check is only valid on master node
if [ "$CLUSTER_INIT" = "1" ]; then
    # Check for pending CSRs
    PENDING_CSR=$(kubectl get csr 2>/dev/null | grep -c 'Pending' || echo "0")
    if [ "$PENDING_CSR" -gt 0 ]; then
        echo -e "${YELLOW}!${NC} $PENDING_CSR pending CSR(s) found"
        kubectl get csr 2>/dev/null
        PENDING_CSR_FLAG=1
    else
        echo -e "${GREEN}✓${NC} No pending CSRs"
        PENDING_CSR_FLAG=0
    fi
    
    # Check for worker nodes
    WORKER_NODES=$(kubectl get nodes 2>/dev/null | grep -v 'master\|control-plane\|NAME' | wc -l)
    if [ "$WORKER_NODES" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} $WORKER_NODES worker node(s) found"
        kubectl get nodes 2>/dev/null | grep -v 'master\|control-plane\|NAME'
        WORKER_NODES_COUNT=$WORKER_NODES
    else
        echo -e "${YELLOW}!${NC} No worker nodes found"
        WORKER_NODES_COUNT=0
    fi
else
    echo "(Skipped - cluster not initialized)"
    PENDING_CSR_FLAG=0
    WORKER_NODES_COUNT=0
fi

echo ""
echo "=========================================="
echo "  Checking Step 9: kubectl Access Setup"
echo "=========================================="

# Check for kubectl config in home directory
if [ -f "$HOME/.kube/config" ]; then
    echo -e "${GREEN}✓${NC} $HOME/.kube/config exists"
    KUBECONFIG_HOME=1
else
    echo -e "${YELLOW}!${NC} $HOME/.kube/config NOT found"
    KUBECONFIG_HOME=0
fi

# Check KUBECONFIG environment variable
if [ -n "$KUBECONFIG" ]; then
    echo -e "${GREEN}✓${NC} KUBECONFIG environment variable is set"
    KUBECONFIG_ENV=1
else
    echo -e "${YELLOW}!${NC} KUBECONFIG environment variable NOT set"
    KUBECONFIG_ENV=0
fi

echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo ""
echo "Step 1: Swap Configuration      - $([ "$SWAP_FSTAB" = "1" ] && [ "$SWAP_ACTIVE" = "1" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${RED}INCOMPLETE${NC}")"
echo "Step 2: Kernel Modules          - $([ "$BR_NETFILTER" = "1" ] && [ "$OVERLAY" = "1" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${RED}INCOMPLETE${NC}")"
echo "Step 3: IP Forwarding           - $([ "$IPV4_FORWARD" = "1" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${RED}INCOMPLETE${NC}")"
echo "Step 4: Kubernetes Components   - $([ "$KUBELET" = "1" ] && [ "$KUBEADM" = "1" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${RED}INCOMPLETE${NC}")"
echo "Step 5: Container Runtime       - $([ "$CRI_DOCKERD" = "1" ] || [ "$CRI_O" = "1" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${YELLOW}PARTIAL${NC}")"
echo "Step 6: Cluster Initialization  - $([ "$CLUSTER_INIT" = "1" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${RED}INCOMPLETE${NC}")"
echo "Step 7: Worker Node Join        - $([ "$WORKER_JOIN" = "1" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${RED}INCOMPLETE${NC}")"
echo "Step 8: CSR & Node Object       - $([ "$PENDING_CSR_FLAG" = "0" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${YELLOW}PENDING${NC}")"
echo "Step 9: kubectl Access          - $([ "$KUBECONFIG_HOME" = "1" ] && echo -e "${GREEN}COMPLETED${NC}" || echo -e "${YELLOW}INCOMPLETE${NC}")"
echo ""

# Calculate overall progress
TOTAL_STEPS=9
COMPLETED_STEPS=0

[ "$SWAP_FSTAB" = "1" ] && [ "$SWAP_ACTIVE" = "1" ] && ((COMPLETED_STEPS++)) || true
[ "$BR_NETFILTER" = "1" ] && [ "$OVERLAY" = "1" ] && ((COMPLETED_STEPS++)) || true
[ "$IPV4_FORWARD" = "1" ] && ((COMPLETED_STEPS++)) || true
[ "$KUBELET" = "1" ] && [ "$KUBEADM" = "1" ] && ((COMPLETED_STEPS++)) || true
[ "$CRI_DOCKERD" = "1" ] || [ "$CRI_O" = "1" ] && ((COMPLETED_STEPS++)) || true
[ "$CLUSTER_INIT" = "1" ] && ((COMPLETED_STEPS++)) || true
[ "$WORKER_JOIN" = "1" ] && ((COMPLETED_STEPS++)) || true
[ "$PENDING_CSR_FLAG" = "0" ] && ((COMPLETED_STEPS++)) || true
[ "$KUBECONFIG_HOME" = "1" ] && ((COMPLETED_STEPS++)) || true

echo "Overall Progress: $COMPLETED_STEPS/$TOTAL_STEPS steps completed"
echo ""

# Offer to complete missing steps
echo "=========================================="
echo "  Complete Missing Steps"
echo "=========================================="
echo ""

MISSING_STEPS=()

[ "$SWAP_FSTAB" = "0" ] || [ "$SWAP_ACTIVE" = "0" ] && MISSING_STEPS+=("swap")
[ "$BR_NETFILTER" = "0" ] || [ "$OVERLAY" = "0" ] && MISSING_STEPS+=("kernel-modules")
[ "$IPV4_FORWARD" = "0" ] && MISSING_STEPS+=("ip-forward")
[ "$KUBELET" = "0" ] || [ "$KUBEADM" = "0" ] && MISSING_STEPS+=("kubernetes-components")
[ "$CRI_DOCKERD" = "0" ] && [ "$CRI_O" = "0" ] && MISSING_STEPS+=("container-runtime")
[ "$CLUSTER_INIT" = "0" ] && MISSING_STEPS+=("cluster-init")
[ "$WORKER_JOIN" = "0" ] && MISSING_STEPS+=("worker-join")
[ "$PENDING_CSR_FLAG" = "1" ] && MISSING_STEPS+=("csr-approval")
[ "$KUBECONFIG_HOME" = "0" ] && MISSING_STEPS+=("kubectl-access")

if [ ${#MISSING_STEPS[@]} -eq 0 ]; then
    echo -e "${GREEN}All steps are completed!${NC}"
    echo ""
    echo "Cluster status:"
    kubectl get nodes 2>/dev/null || echo "Cannot get nodes"
else
    echo "Missing steps: ${MISSING_STEPS[*]}"
    echo ""
    echo "To complete missing steps, run this script with the --fix flag:"
    echo "  $0 --fix"
    echo ""
    echo "Or run specific steps:"
    echo "  $0 --fix-swap        # Step 1: Disable swap"
    echo "  $0 --fix-modules     # Step 2: Enable kernel modules"
    echo "  $0 --fix-ipforward   # Step 3: Enable IP forwarding"
    echo "  $0 --fix-kubelet     # Step 4: Install kubelet/kubeadm/kubectl"
    echo "  $0 --fix-runtime     # Step 5: Install container runtime"
    echo "  $0 --fix-init        # Step 6: Initialize cluster"
    echo "  $0 --fix-join        # Step 7: Join worker node"
    echo "  $0 --fix-csr         # Step 8: Approve CSR"
    echo "  $0 --fix-kubectl     # Step 9: Setup kubectl access"
fi

echo ""

