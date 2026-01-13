# Comprehensive Guide: Service Management System in Kubernetes

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Technology Stack](#technology-stack)
4. [Quick Start](#quick-start)
5. [Kubernetes Cluster Setup](#kubernetes-cluster-setup)
   - [Prerequisites](#prerequisites)
   - [Setting up Kubernetes on Server (Control Plane)](#setting-up-kubernetes-on-server-control-plane)
   - [Setting up Worker Nodes](#setting-up-worker-nodes)
   - [Cluster Configuration](#cluster-configuration)
6. [Application Deployment](#application-deployment)
7. [Monitoring and Metrics](#monitoring-and-metrics)
8. [Troubleshooting](#troubleshooting)
9. [Security and Best Practices](#security-and-best-practices)
10. [Maintenance](#maintenance)

---

## Project Overview

**Service Management System** is a comprehensive solution for managing computer equipment servicing. It provides:

- Device tracking (printers, servers, routers, workstations, UPS)
- Service type management (toner replacement, cleaning, firmware updates)
- Service history with automatic next service date calculation
- REST API for integration
- Web interface for management
- Prometheus metrics for monitoring
- Grafana dashboards for visualization
- Centralized logging with Loki

### Key Features

- **Device Management**: CRUD operations for equipment
- **Service Types**: Configurable service categories with intervals
- **Service History**: Detailed records with cost tracking
- **Authentication**: User login/logout with role-based access
- **Monitoring**: Real-time metrics and alerting
- **Logging**: Centralized log aggregation

---

## Architecture

```
+-------------------------------------------------------------------------+
|                           Service Management System                      |
+-------------------------------------------------------------------------+
|                                                                              |
|   +-------------+    +-------------+    +-------------+    +-------------+ |
|   |   Grafana   |    | Prometheus  |    |    Loki     |    |   Web UI    | |
|   |  (visual.)  |    |  (metrics)  |    |   (logs)    |    |   (SPA)     | |
|   +------+------+    +------+------+    +------+------+    +------+------+ |
|          |                  |                  |                  |          |
|          +------------------+------------------+------------------+          |
|                                      |                                      |
|                                 +----+----+                                |
|                                 |  Crow   |                                |
|                                 |  C++    |                                |
|                                 +----+----+                                |
|                                      |                                      |
|                                      v                                      |
|                              +---------------+                              |
|                              |   libpqxx     |                              |
|                              |   (PostgreSQL)|                              |
|                              +-------+-------+                              |
|                                      |                                      |
|                              +-------v-------+                              |
|                              |  PostgreSQL   |                              |
|                              |  (car_service)|                              |
|                              +---------------+                              |
|                                                                              |
+-------------------------------------------------------------------------+
```

### Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| Backend | C++ with Crow | REST API server |
| Database | PostgreSQL | Data storage |
| Frontend | HTML5 + Vanilla JS | Web interface |
| Monitoring | Prometheus | Metrics collection |
| Visualization | Grafana | Dashboards |
| Logging | Loki | Log aggregation |
| Container Runtime | Docker + cri-dockerd | Container execution |
| Orchestration | Kubernetes | Container management |

---

## Technology Stack

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| Backend | C++ | C++23 | Core application |
| Web Framework | Crow | latest | HTTP server |
| Database | PostgreSQL | 15-alpine | Data persistence |
| DB Client | libpqxx | 7.7.5 | PostgreSQL connectivity |
| JSON | nlohmann/json | header-only | Data serialization |
| Monitoring | Prometheus | v2.48.0 | Metrics collection |
| Logging | Loki | 2.9.2 | Log aggregation |
| Log Agent | Promtail | 2.9.2 | Log shipping |
| Visualization | Grafana | 10.2.2 | Dashboards |
| Frontend | HTML5 + Vanilla JS | - | User interface |
| Containerization | Docker | latest | Application packaging |
| Orchestration | Kubernetes | 1.24+ | Container management |
| Build System | CMake | 3.10+ | Compilation |

---

## Quick Start

### Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Docker images: `dmitriier/service-system:latest`, `postgres:15`

### Deployment Steps

1. **Create namespace:**
   ```bash
   kubectl create namespace service-system
   ```

2. **Deploy PostgreSQL:**
   ```bash
   kubectl apply -f postgres.yaml
   ```

3. **Deploy application:**
   ```bash
   kubectl apply -f deployment.yaml
   ```

4. **Check deployment:**
   ```bash
   kubectl get pods -n service-system
   ```

5. **Access application:**
   - NodePort: `http://<node-ip>:30080`
   - API: `http://<node-ip>:30080/api/test-db`

---

## Kubernetes Cluster Setup

### Prerequisites

- Ubuntu 20.04+ or similar Linux distribution
- Root or sudo access
- Static IP addresses for all nodes
- Internet connectivity
- At least 2 CPUs, 4GB RAM per node

### Setting up Kubernetes on Server (Control Plane)

#### 1. Update System
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget apt-transport-https
```

#### 2. Disable Swap
```bash
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
```

#### 3. Configure Firewall
```bash
sudo ufw allow 6443/tcp
sudo ufw allow 2379:2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10251/tcp
sudo ufw allow 10252/tcp
sudo ufw allow 30000:32767/tcp
```

#### 4. Install Docker
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

#### 5. Install cri-dockerd
```bash
# Download and install cri-dockerd
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1.3/cri-dockerd_0.3.1.3-0.ubuntu-focal_amd64.deb
sudo dpkg -i cri-dockerd_0.3.1.3-0.ubuntu-focal_amd64.deb

# Configure cri-dockerd
sudo tee /etc/cri-dockerd/config.toml > /dev/null <<EOF
[cri-dockerd]
  socket-path = "/run/cri-dockerd.sock"
  pod-infra-container-image = "k8s.gcr.io/pause:3.6"
  runtime-endpoint = "unix:///var/run/docker.sock"
EOF

sudo systemctl enable cri-dockerd
sudo systemctl start cri-dockerd
```

#### 6. Install Kubernetes Components
```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

#### 7. Configure sysctl
```bash
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system
```

#### 8. Initialize Control Plane
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/cri-dockerd.sock
```

#### 9. Configure kubectl
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 10. Install Network Plugin (Flannel)
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

#### 11. Verify Setup
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Setting up Worker Nodes

#### 1. Repeat Steps 1-7 from Control Plane Setup

#### 2. Join the Cluster
```bash
# Get join command from control plane
kubeadm token create --print-join-command

# Run on worker node
sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash> --cri-socket=unix:///run/cri-dockerd.sock
```

#### 3. Verify Worker Node
```bash
kubectl get nodes
```

### Cluster Configuration

#### Node Labels and Taints
```bash
# Label nodes
kubectl label node worker1 node-role.kubernetes.io/worker=worker
kubectl label node worker2 node-role.kubernetes.io/worker=worker

# Taint control plane (optional)
kubectl taint nodes server node-role.kubernetes.io/control-plane:NoSchedule
```

#### RBAC Configuration
```yaml
# Create service account for application
apiVersion: v1
kind: ServiceAccount
metadata:
  name: service-system-sa
  namespace: service-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: service-system-role
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints"]
  verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: service-system-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: service-system-role
subjects:
- kind: ServiceAccount
  name: service-system-sa
  namespace: service-system
```

---

## Application Deployment

### Database Setup

#### PostgreSQL Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: service-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: "car_service_db"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_PASSWORD
          value: "postgres"
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-storage
        emptyDir: {}
```

#### Database Initialization
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-init
  namespace: service-system
data:
  init.sql: |
    CREATE DATABASE IF NOT EXISTS car_service_db;
    
    \c car_service_db;
    
    CREATE TABLE IF NOT EXISTS Devices (
        device_id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        model VARCHAR(100),
        purchase_date DATE,
        status VARCHAR(20) DEFAULT 'active'
    );
    
    CREATE TABLE IF NOT EXISTS Service_Types (
        service_id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        recommended_interval_months INT,
        standard_cost DECIMAL(10,2)
    );
    
    CREATE TABLE IF NOT EXISTS Service_History (
        record_id SERIAL PRIMARY KEY,
        device_id INT REFERENCES Devices(device_id),
        service_id INT REFERENCES Service_Types(service_id),
        service_date DATE NOT NULL,
        cost DECIMAL(10,2),
        notes TEXT,
        next_due_date DATE
    );
    
    -- Insert sample data
    INSERT INTO Devices (name, model, status) VALUES
    ('Printer HP LaserJet', 'HP LaserJet Pro', 'active'),
    ('Server Dell', 'PowerEdge R740', 'active'),
    ('Router Cisco', 'Cisco 2901', 'maintenance');
    
    INSERT INTO Service_Types (name, recommended_interval_months, standard_cost) VALUES
    ('Замена тонера', 3, 1500.00),
    ('Чистка', 6, 800.00),
    ('Обновление прошивки', 12, 2000.00);
```

### Application Deployment

#### Service System Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: service-system
  namespace: service-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: service-system
  template:
    metadata:
      labels:
        app: service-system
    spec:
      containers:
      - name: service-system
        image: dmitriier/service-system:latest
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          value: "db"
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: "car_service_db"
        - name: DB_USER
          value: "postgres"
        - name: DB_PASSWORD
          value: "postgres"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /api/test-db
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /api/test-db
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### Service Configuration
```yaml
apiVersion: v1
kind: Service
metadata:
  name: service-system
  namespace: service-system
spec:
  type: NodePort
  selector:
    app: service-system
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
---
apiVersion: v1
kind: Service
metadata:
  name: db
  namespace: service-system
spec:
  selector:
    app: db
  ports:
  - port: 5432
    targetPort: 5432
```

### API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/devices` | Get all devices |
| POST | `/api/devices` | Add device |
| PUT | `/api/devices/<id>` | Update device |
| DELETE | `/api/devices/<id>` | Delete device |
| GET | `/api/service-types` | Get service types |
| POST | `/api/service-types` | Add service type |
| GET | `/api/service-history` | Get service history |
| POST | `/api/service-history` | Add service record |
| GET | `/metrics` | Prometheus metrics |

---

## Monitoring and Metrics

### Prometheus Setup

#### Configuration
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'service-system'
    static_configs:
      - targets: ['service-system.service-system.svc.cluster.local:80']
    metrics_path: /metrics
    scrape_interval: 5s

  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
```

#### Metrics Types

| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_total` | Counter | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | Request duration |
| `db_operations_total` | Counter | Database operations |
| `auth_attempts_total` | Counter | Authentication attempts |
| `device_operations_total` | Counter | Device operations |

### Grafana Dashboards

#### Key Dashboards

1. **Service System Overview**
   - HTTP request rate
   - Error rates
   - Database operations
   - Authentication metrics

2. **Performance Metrics**
   - Response times (p50, p95, p99)
   - Throughput
   - Resource usage

3. **System Health**
   - Pod status
   - Node resources
   - Database connections

#### Sample Queries

```promql
# Request rate
sum(rate(http_requests_total[5m]))

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# Response time percentiles
histogram_quantile(0.95, rate(http_request_duration_seconds[5m]))
```

### Loki Logging

#### LogQL Queries

```logql
# Application logs
{app="service-system"} |= "error"

# Database errors
{app="service-system"} |= "database" |= "error"

# API requests
{app="service-system"} |= "/api/"
```

---

## Troubleshooting

### Common Issues

#### Pod Not Starting
```bash
kubectl describe pod <pod-name> -n service-system
kubectl logs <pod-name> -n service-system
```

#### Database Connection Issues
```bash
kubectl exec -it deployment/db -n service-system -- psql -U postgres -d car_service_db
kubectl logs deployment/db -n service-system
```

#### Network Issues
```bash
kubectl get svc -n service-system
kubectl get endpoints -n service-system
```

#### Resource Issues
```bash
kubectl top pods -n service-system
kubectl top nodes
```

### Cluster Issues

#### Node Not Ready
```bash
kubectl describe node <node-name>
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 50
```

#### API Server Issues
```bash
sudo systemctl status kube-apiserver
sudo journalctl -u kube-apiserver -n 50
```

#### etcd Issues
```bash
sudo systemctl status etcd
sudo journalctl -u etcd -n 50
```

### Application Issues

#### High Error Rates
- Check application logs
- Verify database connectivity
- Check resource limits

#### Slow Responses
- Monitor database performance
- Check network latency
- Review application metrics

---

## Security and Best Practices

### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: service-system-policy
  namespace: service-system
spec:
  podSelector:
    matchLabels:
      app: service-system
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: service-system
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: db
    ports:
    - protocol: TCP
      port: 5432
```

### Secrets Management
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secrets
  namespace: service-system
type: Opaque
data:
  username: cG9zdGdyZXM=  # base64 encoded
  password: cG9zdGdyZXM=  # base64 encoded
```

### Resource Limits
```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

---

## Maintenance

### Backup Strategy

#### Database Backup
```bash
kubectl exec deployment/db -n service-system -- pg_dump -U postgres car_service_db > backup.sql
```

#### etcd Backup
```bash
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Updates

#### Application Updates
```bash
kubectl set image deployment/service-system service-system=dmitriier/service-system:v2.0 -n service-system
kubectl rollout status deployment/service-system -n service-system
```

#### Kubernetes Updates
```bash
# Update kubelet
sudo apt update && sudo apt upgrade kubelet

# Drain node
kubectl drain <node-name> --ignore-daemonsets

# Update node
sudo kubeadm upgrade node

# Uncordon node
kubectl uncordon <node-name>
```

### Monitoring Maintenance

#### Log Rotation
```bash
# Configure logrotate for application logs
sudo tee /etc/logrotate.d/service-system > /dev/null <<EOF
/var/log/service-system/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
}
EOF
```

#### Metrics Retention
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

storage:
  tsdb:
    retention.time: 30d
    retention.size: 10GB
```

---

## Conclusion

This comprehensive guide covers the complete setup and management of the Service Management System in a Kubernetes environment. The system provides robust equipment tracking, service management, and monitoring capabilities suitable for enterprise environments.

Key takeaways:
- Proper Kubernetes cluster setup is crucial for reliability
- Monitoring and logging are essential for maintenance
- Security policies should be implemented from the start
- Regular backups and updates ensure system stability

For additional support, refer to the individual component documentation or community resources.
