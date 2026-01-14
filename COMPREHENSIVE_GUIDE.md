# Комплексное руководство: Система управления обслуживанием в Kubernetes

## Содержание

1. [Обзор проекта](#обзор-проекта)
2. [Архитектура](#архитектура)
3. [Технологический стек](#технологический-стек)
4. [Быстрый старт](#быстрый-старт)
5. [Настройка кластера Kubernetes](#настройка-кластера-kubernetes)
   - [Предварительные требования](#предварительные-требования)
   - [Настройка Kubernetes на сервере (Control Plane)](#настройка-kubernetes-на-сервере-control-plane)
   - [Настройка рабочих узлов](#настройка-рабочих-узлов)
   - [Конфигурация кластера](#конфигурация-кластера)
6. [Развертывание приложения](#развертывание-приложения)
7. [Мониторинг и метрики](#мониторинг-и-метрики)
8. [Устранение неисправностей](#устранение-неисправностей)
9. [Безопасность и лучшие практики](#безопасность-и-лучшие-практики)
10. [Обслуживание](#обслуживание)

---

## Обзор проекта

**Система управления обслуживанием** — это комплексное решение для управления обслуживанием компьютерного оборудования. Она предоставляет:

- Отслеживание устройств (принтеры, серверы, роутеры, рабочие станции, ИБП)
- Управление типами обслуживания (замена тонера, чистка, обновление прошивки)
- История обслуживания с автоматическим расчетом следующей даты обслуживания
- REST API для интеграции
- Веб-интерфейс для управления
- Метрики Prometheus для мониторинга
- Дашборды Grafana для визуализации
- Централизованное логирование с Loki

### Ключевые возможности

- **Управление устройствами**: CRUD операции для оборудования
- **Типы обслуживания**: Настраиваемые категории обслуживания с интервалами
- **История обслуживания**: Детальные записи с отслеживанием стоимости
- **Аутентификация**: Вход/выход пользователей с ролевым доступом
- **Мониторинг**: Метрики в реальном времени и оповещения
- **Логирование**: Централизованная агрегация логов

---

## Архитектура

```
+-------------------------------------------------------------------------+
|                           Система управления обслуживанием              |
+-------------------------------------------------------------------------+
|                                                                              |
|   +-------------+    +-------------+    +-------------+    +-------------+ |
|   |   Grafana   |    | Prometheus  |    |    Loki     |    |   Web UI    | |
|   |  (визуал.)  |    |  (метрики)  |    |   (логи)    |    |   (SPA)     | |
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

### Компоненты

| Компонент | Технология | Назначение |
|-----------|------------|---------|
| Backend | C++ с Crow | REST API сервер |
| База данных | PostgreSQL | Хранение данных |
| Frontend | HTML5 + Vanilla JS | Веб-интерфейс |
| Мониторинг | Prometheus | Сбор метрик |
| Визуализация | Grafana | Дашборды |
| Логирование | Loki | Агрегация логов |
| Container Runtime | Docker + cri-dockerd | Выполнение контейнеров |
| Оркестрация | Kubernetes | Управление контейнерами |

---

## Технологический стек

| Компонент | Технология | Версия | Назначение |
|-----------|------------|---------|---------|
| Backend | C++ | C++23 | Основное приложение |
| Web Framework | Crow | latest | HTTP сервер |
| База данных | PostgreSQL | 15-alpine | Хранение данных |
| DB Client | libpqxx | 7.7.5 | Подключение к PostgreSQL |
| JSON | nlohmann/json | header-only | Сериализация данных |
| Мониторинг | Prometheus | v2.48.0 | Сбор метрик |
| Логирование | Loki | 2.9.2 | Агрегация логов |
| Log Agent | Promtail | 2.9.2 | Отправка логов |
| Визуализация | Grafana | 10.2.2 | Дашборды |
| Frontend | HTML5 + Vanilla JS | - | Пользовательский интерфейс |
| Контейнеризация | Docker | latest | Упаковка приложений |
| Оркестрация | Kubernetes | 1.24+ | Управление контейнерами |
| Build System | CMake | 3.10+ | Компиляция |

---

## Быстрый старт

### Предварительные требования

- Кластер Kubernetes (1.24+)
- Настроенный kubectl
- Docker образы: `dmitriier/service-system:latest`, `postgres:15`

### Шаги развертывания

1. **Создайте namespace:**
   ```bash
   kubectl create namespace service-system
   ```

2. **Разверните PostgreSQL:**
   ```bash
   kubectl apply -f postgres.yaml
   ```

3. **Разверните приложение:**
   ```bash
   kubectl apply -f deployment.yaml
   ```

4. **Проверьте развертывание:**
   ```bash
   kubectl get pods -n service-system
   ```

5. **Доступ к приложению:**
   - NodePort: `http://<node-ip>:30080`
   - API: `http://<node-ip>:30080/api/test-db`

---

## Настройка кластера Kubernetes

### Предварительные требования

- Ubuntu 20.04+ или аналогичная Linux дистрибуция
- Доступ root или sudo
- Статические IP адреса для всех узлов
- Доступ к интернету
- Минимум 2 CPU, 4GB RAM на узел

### Настройка Kubernetes на сервере (Control Plane)

#### 1. Обновите систему
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget apt-transport-https
```

#### 2. Отключите Swap
```bash
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab
```

#### 3. Настройте Firewall
```bash
sudo ufw allow 6443/tcp
sudo ufw allow 2379:2380/tcp
sudo ufw allow 10250/tcp
sudo ufw allow 10251/tcp
sudo ufw allow 10252/tcp
sudo ufw allow 30000:32767/tcp
```

#### 4. Установите Docker
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

#### 5. Установите cri-dockerd
```bash
# Скачайте и установите cri-dockerd
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1.3/cri-dockerd_0.3.1.3-0.ubuntu-focal_amd64.deb
sudo dpkg -i cri-dockerd_0.3.1.3-0.ubuntu-focal_amd64.deb

# Настройте cri-dockerd
sudo tee /etc/cri-dockerd/config.toml > /dev/null <<EOF
[cri-dockerd]
  socket-path = "/run/cri-dockerd.sock"
  pod-infra-container-image = "k8s.gcr.io/pause:3.6"
  runtime-endpoint = "unix:///var/run/docker.sock"
EOF

sudo systemctl enable cri-dockerd
sudo systemctl start cri-dockerd
```

#### 6. Установите компоненты Kubernetes
```bash
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

#### 7. Настройте sysctl
```bash
sudo tee /etc/sysctl.d/k8s.conf > /dev/null <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo sysctl --system
```

#### 8. Инициализируйте Control Plane
```bash
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket=unix:///run/cri-dockerd.sock
```

#### 9. Настройте kubectl
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

#### 10. Установите сетевой плагин (Flannel)
```bash
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

#### 11. Проверьте настройку
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Настройка рабочих узлов

#### 1. Повторите шаги 1-7 из настройки Control Plane

#### 2. Присоединитесь к кластеру
```bash
# Получите команду присоединения от control plane
kubeadm token create --print-join-command

# Выполните на рабочем узле
sudo kubeadm join <control-plane-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash> --cri-socket=unix:///run/cri-dockerd.sock
```

#### 3. Проверьте рабочий узел
```bash
kubectl get nodes
```

### Конфигурация кластера

#### Метки узлов и Taints
```bash
# Метки узлов
kubectl label node worker1 node-role.kubernetes.io/worker=worker
kubectl label node worker2 node-role.kubernetes.io/worker=worker

# Taint control plane (опционально)
kubectl taint nodes server node-role.kubernetes.io/control-plane:NoSchedule
```

#### Конфигурация RBAC
```yaml
# Создайте сервисный аккаунт для приложения
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

## Развертывание приложения

### Настройка базы данных

#### Развертывание PostgreSQL
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

#### Инициализация базы данных
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
    
    -- Вставьте пример данных
    INSERT INTO Devices (name, model, status) VALUES
    ('Printer HP LaserJet', 'HP LaserJet Pro', 'active'),
    ('Server Dell', 'PowerEdge R740', 'active'),
    ('Router Cisco', 'Cisco 2901', 'maintenance');
    
    INSERT INTO Service_Types (name, recommended_interval_months, standard_cost) VALUES
    ('Замена тонера', 3, 1500.00),
    ('Чистка', 6, 800.00),
    ('Обновление прошивки', 12, 2000.00);
```

### Развертывание приложения

#### Развертывание системы обслуживания
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

#### Конфигурация сервиса
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

### Конечные точки API

| Метод | Конечная точка | Описание |
|--------|----------------|-------------|
| GET | `/api/devices` | Получить все устройства |
| POST | `/api/devices` | Добавить устройство |
| PUT | `/api/devices/<id>` | Обновить устройство |
| DELETE | `/api/devices/<id>` | Удалить устройство |
| GET | `/api/service-types` | Получить типы обслуживания |
| POST | `/api/service-types` | Добавить тип обслуживания |
| GET | `/api/service-history` | Получить историю обслуживания |
| POST | `/api/service-history` | Добавить запись обслуживания |
| GET | `/metrics` | Метрики Prometheus |

---

## Мониторинг и метрики

### Настройка Prometheus

#### Конфигурация
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

#### Типы метрик

| Метрика | Тип | Описание |
|---------|------|-------------|
| `http_requests_total` | Counter | Общее количество HTTP-запросов |
| `http_request_duration_seconds` | Histogram | Длительность запросов |
| `db_operations_total` | Counter | Операции базы данных |
| `auth_attempts_total` | Counter | Попытки аутентификации |
| `device_operations_total` | Counter | Операции с устройствами |

### Дашборды Grafana

#### Ключевые дашборды

1. **Обзор системы обслуживания**
   - Скорость HTTP-запросов
   - Уровни ошибок
   - Операции базы данных
   - Метрики аутентификации

2. **Метрики производительности**
   - Времена отклика (p50, p95, p99)
   - Пропускная способность
   - Использование ресурсов

3. **Здоровье системы**
   - Статус подов
   - Ресурсы узлов
   - Соединения базы данных

#### Примеры запросов

```promql
# Скорость запросов
sum(rate(http_requests_total[5m]))

# Уровень ошибок
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))

# Процентили времени отклика
histogram_quantile(0.95, rate(http_request_duration_seconds[5m]))
```

### Логирование Loki

#### Запросы LogQL

```logql
# Логи приложения
{app="service-system"} |= "error"

# Ошибки базы данных
{app="service-system"} |= "database" |= "error"

# Запросы API
{app="service-system"} |= "/api/"
```

---

## Устранение неисправностей

### Распространенные проблемы

#### Под не запускается
```bash
kubectl describe pod <pod-name> -n service-system
kubectl logs <pod-name> -n service-system
```

#### Проблемы подключения к базе данных
```bash
kubectl exec -it deployment/db -n service-system -- psql -U postgres -d car_service_db
kubectl logs deployment/db -n service-system
```

#### Сетевые проблемы
```bash
kubectl get svc -n service-system
kubectl get endpoints -n service-system
```

#### Проблемы с ресурсами
```bash
kubectl top pods -n service-system
kubectl top nodes
```

### Проблемы кластера

#### Узел не готов
```bash
kubectl describe node <node-name>
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 50
```

#### Проблемы API-сервера
```bash
sudo systemctl status kube-apiserver
sudo journalctl -u kube-apiserver -n 50
```

#### Проблемы etcd
```bash
sudo systemctl status etcd
sudo journalctl -u etcd -n 50
```

### Проблемы приложения

#### Высокие уровни ошибок
- Проверьте логи приложения
- Проверьте подключение к базе данных
- Проверьте лимиты ресурсов

#### Медленные ответы
- Мониторьте производительность базы данных
- Проверьте сетевую задержку
- Просмотрите метрики приложения

---

## Безопасность и лучшие практики

### Сетевые политики
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

### Управление секретами
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

### Лимиты ресурсов
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

## Обслуживание

### Стратегия резервного копирования

#### Резервное копирование базы данных
```bash
kubectl exec deployment/db -n service-system -- pg_dump -U postgres car_service_db > backup.sql
```

#### Резервное копирование etcd
```bash
sudo ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key
```

### Обновления

#### Обновления приложения
```bash
kubectl set image deployment/service-system service-system=dmitriier/service-system:v2.0 -n service-system
kubectl rollout status deployment/service-system -n service-system
```

#### Обновления Kubernetes
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

### Обслуживание мониторинга

#### Ротация логов
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

#### Хранение метрик
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

## Заключение

Это комплексное руководство охватывает полную настройку и управление системой управления обслуживанием в среде Kubernetes. Система предоставляет надежное отслеживание оборудования, управление обслуживанием и возможности мониторинга, подходящие для корпоративных сред.

Ключевые выводы:
- Правильная настройка кластера Kubernetes имеет решающее значение для надежности
- Мониторинг и логирование необходимы для обслуживания
- Политики безопасности должны быть реализованы с самого начала
- Регулярные резервные копии и обновления обеспечивают стабильность системы

Для дополнительной поддержки обратитесь к документации отдельных компонентов или ресурсам сообщества.
