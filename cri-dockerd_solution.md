# Kubernetes 1.24+ with Docker - cri-dockerd Installation Solution

## Problem Analysis

The error `dial tcp [::1]:10248: connect: connection refused` occurs because:
- Kubernetes 1.24+ removed in-tree Docker support
- Docker doesn't provide a CRI (Container Runtime Interface) endpoint by default
- You need **cri-dockerd** to bridge Docker to CRI

## Solution - Step by Step

### Step 1: Install cri-dockerd

**Option A: Use the existing package (Recommended)**
```bash
cd /home/adminstd/Desktop
sudo dpkg -i cri-dockerd_0.3.1.3-0.ubuntu-jammy_amd64.deb
sudo apt-get install -f -y  # Fix any dependency issues
```

**Option B: If package installation fails, download from GitHub**
```bash
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1/cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb
sudo dpkg -i cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb
sudo apt-get install -f -y
```

### Step 2: Configure cri-dockerd

```bash
# Create configuration directory
sudo mkdir -p /etc/cri-dockerd

# Create cri-dockerd configuration
sudo bash -c 'cat > /etc/cri-dockerd/config.toml << EOF
[grpc]
  address = "/run/cri-dockerd.sock"
[cri_socket]
  docker_endpoint = "unix:///var/run/docker.sock"
EOF'
```

### Step 3: Configure kubelet to use cri-dockerd

```bash
# Create kubelet override
sudo mkdir -p /etc/systemd/system/kubelet.service.d/
sudo bash -c 'cat > /etc/systemd/system/kubelet.service.d/20-cri-dockerd.conf << EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/cri-dockerd.sock"
EOF'
```

### Step 4: Enable and start cri-dockerd

```bash
sudo systemctl daemon-reload
sudo systemctl enable cri-dockerd
sudo systemctl start cri-dockerd
```

### Step 5: Verify cri-dockerd is running

```bash
sudo systemctl status cri-dockerd
```

Expected output should show `active (running)`.

### Step 6: Restart kubelet

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Step 7: Verify the setup

```bash
# Check kubelet health
curl -sSL http://localhost:10248/healthz
```

Expected output: `ok`

## Complete One-Command Solution

Run all commands at once:

```bash
# Install cri-dockerd
cd /home/adminstd/Desktop
sudo dpkg -i cri-dockerd_0.3.1.3-0.ubuntu-jammy_amd64.deb 2>/dev/null || \
wget -q https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1/cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb && \
sudo dpkg -i cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb
sudo apt-get install -f -y

# Configure cri-dockerd
sudo mkdir -p /etc/cri-dockerd
sudo bash -c 'cat > /etc/cri-dockerd/config.toml << EOF
[grpc]
  address = "/run/cri-dockerd.sock"
[cri_socket]
  docker_endpoint = "unix:///var/run/docker.sock"
EOF'

# Configure kubelet
sudo mkdir -p /etc/systemd/system/kubelet.service.d/
sudo bash -c 'cat > /etc/systemd/system/kubelet.service.d/20-cri-dockerd.conf << EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/cri-dockerd.sock"
EOF'

# Start services
sudo systemctl daemon-reload
sudo systemctl enable cri-dockerd
sudo systemctl start cri-dockerd
sudo systemctl restart kubelet

# Verify
sleep 5
curl -sSL http://localhost:10248/healthz
```

## Troubleshooting

If you still encounter issues:

1. **Check cri-dockerd status:**
   ```bash
   sudo systemctl status cri-dockerd
   ```

2. **Check kubelet logs:**
   ```bash
   sudo journalctl -u kubelet -n 50 --no-pager
   ```

3. **Check cri-dockerd logs:**
   ```bash
   sudo journalctl -u cri-dockerd -n 50 --no-pager
   ```

4. **Verify socket exists:**
   ```bash
   ls -la /run/cri-dockerd.sock
   ```

## After Installation

Once installed successfully, you can retry the kubeadm init:

```bash
sudo /usr/local/bin/kubeadm init --config /etc/kubernetes/kubeadm-config.yaml --ignore-preflight-errors=all
```

