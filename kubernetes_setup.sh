#!/bin/bash

# Kubernetes Setup - Complete All Missing Steps
# This script performs all Kubernetes setup steps from the original task

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBERNETES_VERSION="1.28.0-00"
CRI_O_VERSION="1.28"

echo "=========================================="
echo "  Kubernetes Complete Setup Script"
echo "=========================================="
echo ""

# Function to run steps that need root
run_as_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}This step requires root. Running with sudo...${NC}"
        sudo "$@"
    else
        "$@"
    fi
}

# ==========================================
# STEP 1: Disable Swap
# ==========================================
fix_swap() {
    echo "=========================================="
    echo "  Step 1: Disabling Swap Memory"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This step must be run as root"
        echo "Usage: sudo $0 --fix-swap"
        exit 1
    fi
    
    echo "Disabling swap temporarily..."
    swapoff -a
    echo "✓ Swap disabled"
    echo ""
    
    echo "Removing swap file..."
    if [ -f /swap.img ]; then
        rm -f /swap.img
        echo "✓ /swap.img removed"
    elif [ -f /swapfile ]; then
        rm -f /swapfile
        echo "✓ /swapfile removed"
    else
        echo "✓ No swap file found"
    fi
    echo ""
    
    echo "Commenting out swap in /etc/fstab..."
    if grep -q '^[^#].*swap' /etc/fstab; then
        sed -i '/swap/s/^/#/' /etc/fstab
        echo "✓ Swap line commented in /etc/fstab"
    else
        echo "✓ No swap line found in /etc/fstab"
    fi
    
    echo ""
    echo -e "${GREEN}Step 1 completed!${NC}"
    echo ""
}

# ==========================================
# STEP 2: Enable Kernel Modules
# ==========================================
fix_kernel_modules() {
    echo "=========================================="
    echo "  Step 2: Enabling Kernel Modules"
    echo "=========================================="
    echo ""
    
    run_as_root modprobe br_netfilter
    echo "✓ br_netfilter module loaded"
    
    run_as_root modprobe overlay
    echo "✓ overlay module loaded"
    echo ""
    
    echo "Adding modules to /etc/modules for persistence..."
    if ! grep -q 'br_netfilter' /etc/modules 2>/dev/null; then
        echo "br_netfilter" >> /etc/modules
        echo "✓ br_netfilter added to /etc/modules"
    else
        echo "✓ br_netfilter already in /etc/modules"
    fi
    
    if ! grep -q 'overlay' /etc/modules 2>/dev/null; then
        echo "overlay" >> /etc/modules
        echo "✓ overlay added to /etc/modules"
    else
        echo "✓ overlay already in /etc/modules"
    fi
    
    echo ""
    echo -e "${GREEN}Step 2 completed!${NC}"
    echo ""
}

# ==========================================
# STEP 3: IP Forwarding
# ==========================================
fix_ip_forward() {
    echo "=========================================="
    echo "  Step 3: Enabling IP Forwarding"
    echo "=========================================="
    echo ""
    
    echo "Enabling IP forwarding..."
    run_as_root bash -c 'echo 1 > /proc/sys/net/ipv4/ip_forward'
    echo "✓ IP forwarding enabled"
    echo ""
    
    echo "Making the change persistent..."
    if ! grep -q '^net.ipv4.ip_forward' /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        echo "✓ Added to /etc/sysctl.conf"
    else
        echo "✓ Already configured in /etc/sysctl.conf"
    fi
    
    # Apply immediately
    sysctl -p > /dev/null 2>&1 || true
    
    echo ""
    echo -e "${GREEN}Step 3 completed!${NC}"
    echo ""
}

# ==========================================
# STEP 4: Install kubelet, kubeadm, kubectl
# ==========================================
fix_kubernetes_components() {
    echo "=========================================="
    echo "  Step 4: Installing Kubernetes Components"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This step must be run as root"
        echo "Usage: sudo $0 --fix-kubelet"
        exit 1
    fi
    
    echo "Updating package lists..."
    apt-get update -qq
    echo ""
    
    echo "Installing prerequisites..."
    apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    echo ""
    
    echo "Adding Kubernetes GPG key..."
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
    echo "✓ Kubernetes GPG key added"
    echo ""
    
    echo "Adding Kubernetes repository..."
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
    echo "✓ Kubernetes repository added"
    echo ""
    
    echo "Updating package lists again..."
    apt-get update -qq
    echo ""
    
    echo "Installing kubelet, kubeadm, kubectl..."
    apt-get install -y kubelet=${KUBERNETES_VERSION} kubeadm=${KUBERNETES_VERSION} kubectl=${KUBERNETES_VERSION}
    echo ""
    
    echo "Marking packages as held (prevent auto-updates)..."
    apt-mark hold kubelet kubeadm kubectl
    echo "✓ Packages marked as hold"
    echo ""
    
    echo "Installed versions:"
    kubeadm version
    kubectl version --client
    kubelet --version
    echo ""
    
    echo -e "${GREEN}Step 4 completed!${NC}"
    echo ""
}

# ==========================================
# STEP 5: Install Container Runtime (CRI-O)
# ==========================================
fix_container_runtime() {
    echo "=========================================="
    echo "  Step 5: Installing Container Runtime (CRI-O)"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This step must be run as root"
        echo "Usage: sudo $0 --fix-runtime"
        exit 1
    fi
    
    echo "Installing CRI-O for Kubernetes $KUBERNETES_VERSION..."
    echo ""
    
    # Install prerequisites
    echo "Installing prerequisites..."
    apt-get install -y curl gnupg lsb-release
    
    # Add CRI-O repository
    echo "Adding CRI-O repository..."
    OS="xUbuntu_22.04"
    CRIO_VERSION="$CRI_O_VERSION"
    
    echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/ /" > /etc/apt/sources.list.d/cri-o.list
    
    # Add GPG key
    curl -fsSL https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/$CRIO_VERSION/$OS/Release.key | gpg --dearmor -o /usr/share/keyrings/cri-o-archive-keyring.gpg
    
    echo "Updating package lists..."
    apt-get update -qq
    
    echo "Installing CRI-O..."
    apt-get install -y cri-o cri-o-runc
    echo ""
    
    echo "Enabling and starting CRI-O..."
    systemctl enable crio
    systemctl start crio
    echo "✓ CRI-O service enabled and started"
    echo ""
    
    echo "CRI-O status:"
    systemctl status crio --no-pager
    echo ""
    
    echo -e "${GREEN}Step 5 completed!${NC}"
    echo ""
}

# ==========================================
# ALTERNATIVE STEP 5: Install cri-dockerd
# ==========================================
fix_cri_dockerd() {
    echo "=========================================="
    echo "  Step 5 (Alternative): Installing cri-dockerd"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This step must be run as root"
        echo "Usage: sudo $0 --fix-cri-dockerd"
        exit 1
    fi
    
    echo "Installing cri-dockerd..."
    echo ""
    
    # Check if package exists locally
    if [ -f "$SCRIPT_DIR/cri-dockerd_0.3.1.3-0.ubuntu-jammy_amd64.deb" ]; then
        echo "Installing from local package..."
        dpkg -i "$SCRIPT_DIR/cri-dockerd_0.3.1.3-0.ubuntu-jammy_amd64.deb" 2>/dev/null || true
        apt-get install -f -y -qq
    elif [ -f "$SCRIPT_DIR/cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb" ]; then
        echo "Installing from local package (v0.3.1)..."
        dpkg -i "$SCRIPT_DIR/cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb" 2>/dev/null || true
        apt-get install -f -y -qq
    else
        echo "Downloading from GitHub..."
        TEMP_DEB=$(mktemp)
        wget -q -O "$TEMP_DEB" https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1/cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb || {
            echo "Downloading generic version..."
            wget -q -O "$TEMP_DEB" https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1/cri-dockerd_0.3.1-0.debian.bullseye_amd64.deb
        }
        dpkg -i "$TEMP_DEB" 2>/dev/null || true
        apt-get install -f -y -qq
        rm -f "$TEMP_DEB"
    fi
    
    echo "Configuring cri-dockerd..."
    mkdir -p /etc/cri-dockerd
    
    cat > /etc/cri-dockerd/config.toml << 'EOF'
[grpc]
  address = "/run/cri-dockerd.sock"
[cri_socket]
  docker_endpoint = "unix:///var/run/docker.sock"
EOF
    
    echo "Configuring kubelet to use cri-dockerd..."
    mkdir -p /etc/systemd/system/kubelet.service.d/
    
    cat > /etc/systemd/system/kubelet.service.d/20-cri-dockerd.conf << 'EOF'
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/cri-dockerd.sock"
EOF
    
    echo "Starting cri-dockerd..."
    systemctl daemon-reload
    systemctl enable cri-dockerd
    systemctl start cri-dockerd
    
    echo "Restarting kubelet..."
    systemctl restart kubelet
    
    echo ""
    echo -e "${GREEN}Step 5 (cri-dockerd) completed!${NC}"
    echo ""
}

# ==========================================
# STEP 6: Initialize Cluster
# ==========================================
fix_cluster_init() {
    echo "=========================================="
    echo "  Step 6: Initializing Cluster"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This step must be run as root"
        echo "Usage: sudo $0 --fix-init"
        exit 1
    fi
    
    echo "Initializing Kubernetes cluster..."
    echo "Using pod-network-cidr=10.100.0.0/16"
    echo ""
    
    kubeadm init --pod-network-cidr=10.100.0.0/16
    
    echo ""
    echo -e "${GREEN}Cluster initialized successfully!${NC}"
    echo ""
    
    echo "Setting up kubectl access for root..."
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    echo ""
    
    echo "To start using the cluster, run:"
    echo "  export KUBECONFIG=\$HOME/.kube/config"
    echo "  kubectl get nodes"
    echo ""
    
    echo "To add worker nodes, run the following on each worker:"
    echo "  kubeadm join <master-ip>:6443 --token <token> \\"
    echo "    --discovery-token-ca-cert-hash sha256:<hash>"
    echo ""
    
    echo -e "${GREEN}Step 6 completed!${NC}"
    echo ""
}

# ==========================================
# STEP 7: Join Worker Node
# ==========================================
fix_worker_join() {
    echo "=========================================="
    echo "  Step 7: Joining Worker Node to Cluster"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        echo "ERROR: This step must be run as root"
        echo "Usage: sudo $0 --fix-join"
        exit 1
    fi
    
    echo "This step requires a join command from the master node."
    echo ""
    echo "Get the join command from the master node:"
    echo "  kubectl create token bootstrap"
    echo ""
    echo "Or on the master node, run:"
    echo "  kubeadm token create --print-join-command"
    echo ""
    
    read -p "Enter the full kubeadm join command (or press Enter to skip): " JOIN_COMMAND
    
    if [ -n "$JOIN_COMMAND" ]; then
        echo ""
        echo "Executing join command..."
        eval "$JOIN_COMMAND"
        echo ""
        echo -e "${GREEN}Worker node joined successfully!${NC}"
    else
        echo "Skipped."
    fi
    
    echo ""
}

# ==========================================
# STEP 8: Approve CSR and Create Node Object
# ==========================================
fix_csr() {
    echo "=========================================="
    echo "  Step 8: Approving CSR and Creating Node"
    echo "=========================================="
    echo ""
    
    echo "Checking pending CSRs..."
    kubectl get csr
    echo ""
    
    echo "Approving all pending CSRs..."
    kubectl get csr -o name | xargs kubectl certificate approve
    echo "✓ CSRs approved"
    echo ""
    
    echo "Checking for worker nodes..."
    kubectl get nodes
    echo ""
    
    echo "If a worker node is not showing up, creating Node object manually..."
    kubectl create -f - <<'EOF'
apiVersion: v1
kind: Node
metadata:
  name: worker1
  labels:
    kubernetes.io/hostname: worker1
spec:
  podCIDR: 10.244.1.0/24
EOF
    
    echo ""
    echo -e "${GREEN}Step 8 completed!${NC}"
    echo ""
}

# ==========================================
# STEP 9: Setup kubectl Access
# ==========================================
fix_kubectl_access() {
    echo "=========================================="
    echo "  Step 9: Setting up kubectl Access"
    echo "=========================================="
    echo ""
    
    echo "Copying admin.conf to home directory..."
    mkdir -p $HOME/.kube
    
    if [ -f /etc/kubernetes/admin.conf ]; then
        cp /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config
        chmod 600 $HOME/.kube/config
        echo "✓ Config copied to $HOME/.kube/config"
        
        echo ""
        echo "Verifying access..."
        export KUBECONFIG=$HOME/.kube/config
        kubectl cluster-info
        echo ""
    else
        echo -e "${RED}ERROR: /etc/kubernetes/admin.conf not found${NC}"
        echo "Cluster may not be initialized yet."
    fi
    
    echo "To make this permanent, add to ~/.bashrc or ~/.profile:"
    echo "  export KUBECONFIG=\$HOME/.kube/config"
    echo ""
    
    echo -e "${GREEN}Step 9 completed!${NC}"
    echo ""
}

# ==========================================
# Run All Steps
# ==========================================
run_all() {
    echo "=========================================="
    echo "  Running All Setup Steps"
    echo "=========================================="
    echo ""
    
    echo -e "${YELLOW}Running Step 1: Disable Swap...${NC}"
    fix_swap
    
    echo -e "${YELLOW}Running Step 2: Enable Kernel Modules...${NC}"
    fix_kernel_modules
    
    echo -e "${YELLOW}Running Step 3: IP Forwarding...${NC}"
    fix_ip_forward
    
    echo -e "${YELLOW}Running Step 4: Install Kubernetes Components...${NC}"
    fix_kubernetes_components
    
    echo -e "${YELLOW}Running Step 5: Install Container Runtime...${NC}"
    fix_cri_dockerd
    
    echo -e "${YELLOW}Running Step 6: Initialize Cluster...${NC}"
    fix_cluster_init
    
    echo -e "${YELLOW}Running Step 7: Join Worker Node...${NC}"
    fix_worker_join
    
    echo -e "${YELLOW}Running Step 8: Approve CSR...${NC}"
    fix_csr
    
    echo -e "${YELLOW}Running Step 9: Setup kubectl Access...${NC}"
    fix_kubectl_access
    
    echo "=========================================="
    echo "  All Steps Completed!"
    echo "=========================================="
    echo ""
    echo "Cluster status:"
    export KUBECONFIG=$HOME/.kube/config
    kubectl get nodes
    echo ""
}

# ==========================================
# Main Logic
# ==========================================
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --check         Check current setup status"
    echo "  --fix           Complete all missing steps"
    echo "  --fix-all       Run all setup steps"
    echo "  --fix-swap      Step 1: Disable swap"
    echo "  --fix-modules   Step 2: Enable kernel modules"
    echo "  --fix-ipforward Step 3: Enable IP forwarding"
    echo "  --fix-kubelet   Step 4: Install kubelet/kubeadm/kubectl"
    echo "  --fix-runtime   Step 5: Install container runtime (CRI-O)"
    echo "  --fix-cri-dockerd  Step 5 alt: Install cri-dockerd"
    echo "  --fix-init      Step 6: Initialize cluster"
    echo "  --fix-join      Step 7: Join worker node"
    echo "  --fix-csr       Step 8: Approve CSR"
    echo "  --fix-kubectl   Step 9: Setup kubectl access"
    echo "  --help          Show this help message"
    echo ""
}

# Main
case "$1" in
    --check)
        "$SCRIPT_DIR/check_kubernetes_setup.sh"
        ;;
    --fix)
        # Run only missing steps - first check
        "$SCRIPT_DIR/check_kubernetes_setup.sh" | tee /tmp/kubernetes_check.log
        
        echo ""
        echo "Running fix for missing steps..."
        echo ""
        
        # Parse check results and run missing fixes
        if grep -q "Swap Configuration.*INCOMPLETE" /tmp/kubernetes_check.log; then
            fix_swap
        fi
        
        if grep -q "Kernel Modules.*INCOMPLETE" /tmp/kubernetes_check.log; then
            fix_kernel_modules
        fi
        
        if grep -q "IP Forwarding.*INCOMPLETE" /tmp/kubernetes_check.log; then
            fix_ip_forward
        fi
        
        if grep -q "Kubernetes Components.*INCOMPLETE" /tmp/kubernetes_check.log; then
            fix_kubernetes_components
        fi
        
        if grep -q "Container Runtime.*INCOMPLETE" /tmp/kubernetes_check.log; then
            fix_cri_dockerd
        fi
        
        if grep -q "Cluster Initialization.*INCOMPLETE" /tmp/kubernetes_check.log; then
            fix_cluster_init
        fi
        
        if grep -q "Worker Node Join.*INCOMPLETE" /tmp/kubernetes_check.log; then
            fix_worker_join
        fi
        
        if grep -q "CSR.*PENDING" /tmp/kubernetes_check.log; then
            fix_csr
        fi
        
        if grep -q "kubectl Access.*INCOMPLETE" /tmp/kubernetes_check.log; then
            fix_kubectl_access
        fi
        
        echo "=========================================="
        echo "  All Missing Steps Completed!"
        echo "=========================================="
        ;;
    --fix-all)
        run_all
        ;;
    --fix-swap)
        fix_swap
        ;;
    --fix-modules)
        fix_kernel_modules
        ;;
    --fix-ipforward)
        fix_ip_forward
        ;;
    --fix-kubelet)
        fix_kubernetes_components
        ;;
    --fix-runtime)
        fix_container_runtime
        ;;
    --fix-cri-dockerd)
        fix_cri_dockerd
        ;;
    --fix-init)
        fix_cluster_init
        ;;
    --fix-join)
        fix_worker_join
        ;;
    --fix-csr)
        fix_csr
        ;;
    --fix-kubectl)
        fix_kubectl_access
        ;;
    --help|-h)
        show_usage
        ;;
    *)
        show_usage
        echo ""
        echo "First, let's check your current setup status..."
        echo ""
        "$SCRIPT_DIR/check_kubernetes_setup.sh"
        ;;
esac

