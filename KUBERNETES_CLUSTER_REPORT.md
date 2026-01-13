# Kubernetes Cluster Status Report

---

## 1. Общее описание кластера

### 1.1 Введение

Kubernetes (K8s) — это открытая платформа для оркестрации контейнеров, которая автоматизирует развёртывание, масштабирование и управление контейнеризированными приложениями. Данный кластер развёрнут для обеспечения работы **Service Management System** — системы управления обслуживанием компьютерного оборудования.

### 1.2 Цели развёртывания

| Цель | Описание |
|------|----------|
| **Высокая доступность** | Автоматическое перезапуска и распределение подов между узлами |
| **Масштабируемость** | Возможность горизонтального масштабирования приложения |
| **Изоляция** | Использование namespace для разделения окружений |
| **Мониторинг** | Сбор метрик, логов и алертинг |
| **Управление состоянием** | Хранение данных в PostgreSQL с автоматической инициализацией |

### 1.3 Версия и компоненты

| Компонент | Версия | Назначение |
|-----------|--------|------------|
| Kubernetes | 1.24+ | Платформа оркестрации |
| Docker | 20.10+ | Container Runtime |
| cri-dockerd | 0.3.1.3 | Мост между Docker и CRI |
| PostgreSQL | 15-alpine | База данных |
| Prometheus | latest | Сбор метрик |
| Grafana | latest | Визуализация |

---

## 2. Архитектура кластера

### 2.1 Общая схема

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Cluster                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────┐    ┌─────────────────────┐                  │
│  │   Control Plane     │    │      Worker 1       │                  │
│  │   (Master Node)     │    │   192.168.1.75      │                  │
│  ├─────────────────────┤    ├─────────────────────┤                  │
│  │ • etcd              │    │ • kubelet           │                  │
│  │ • kube-apiserver    │    │ • container runtime │                  │
│  │ • kube-controller   │    │ • kube-proxy        │                  │
│  │ • kube-scheduler    │    │ • pods:             │                  │
│  │ • kubelet           │    │   - service-system  │                  │
│  │ • cri-dockerd       │    │   - db (если тут)   │                  │
│  └─────────────────────┘    └─────────────────────┘                  │
│         192.168.1.74                       │                         │
│                                             │                         │
│  ┌─────────────────────┐                   │                         │
│  │      Worker 2       │◄──────────────────┘                         │
│  │   192.168.1.76      │                                            │
│  ├─────────────────────┤                                            │
│  │ • kubelet           │                                            │
│  │ • container runtime │                                            │
│  │ • kube-proxy        │                                            │
│  │ • pods:             │                                            │
│  │   - service-system  │                                            │
│  └─────────────────────┘                                            │
│                                                                       │
├─────────────────────────────────────────────────────────────────────┤
│                         Network Layer                                │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Pod Network: 10.244.0.0/16 (flannel/calico)                 │    │
│  │  Service Network: 10.96.0.0/12                               │    │
│  └─────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Структура сети

| Сеть | Диапазон | Назначение |
|------|----------|------------|
| **Pod Network** | 10.244.0.0/16 | Внутренняя сеть подов |
| **Service Network** | 10.96.0.0/12 | Виртуальные IP сервисов |
| **Node Network** | 192.168.1.0/24 | Физическая сеть узлов |
| **Pod CIDR Worker 1** | 10.244.1.0/24 | Поды на worker1 |
| **Pod CIDR Worker 2** | 10.244.2.0/24 | Поды на worker2 |

---

## 3. Функции кластера

### 3.1 Основные функции

#### 3.1.1 Оркестрация контейнеров
- **Планирование**: Kubernetes автоматически размещает поды на узлах с достаточными ресурсами
- **Распределение нагрузки**: Балансировка между репликами приложения
- **Аффинити/Антиаффинити**: Правила размещения подов для отказоустойчивости

#### 3.1.2 Управление состоянием (State Management)
- **Deployment**: Гарантирует желаемое количество реплик подов
- **StatefulSet**: Управление состоящими приложениями (например, БД)
- **ConfigMap/Secret**: Хранение конфигурации и секретов

#### 3.1.3 Обнаружение сервисов (Service Discovery)
- **ClusterIP**: Внутренний IP для взаимодействия между подами
- **NodePort**: Доступ к сервисам снаружи кластера
- **DNS**: Автоматическое разрешение имён сервисов

#### 3.1.4 Балансировка нагрузки
- Встроенный kube-proxy распределяет трафик между подами
- Автоматическое исключение недоступных подов

#### 3.1.5 Самовосстановление
- Автоматический перезапуск упавших контейнеров
- Замена нездоровых узлов
- Роллаут обновлений с откатом при проблемах

### 3.2 Дополнительные функции

| Функция | Описание | Реализация |
|---------|----------|------------|
| **Мониторинг** | Сбор метрик и логов | Prometheus + Grafana + Loki |
| **Логирование** | Централизованное хранение логов | Loki + Promtail |
| **Хранилище** | УправлениеPersistent Volumes | emptyDir, PVC |
| **Ресурсы** | Лимиты и запросы ресурсов | requests/limits в подах |
| **Секреты** | Безопасное хранение паролей | Environment variables |

---

## 4. Роли и компоненты узлов (Nodes)

### 4.1 Control Plane (Master Node)

#### 4.1.1 Расположение
- **IP**: 192.168.1.74
- **Роль**: Управление кластером

#### 4.1.2 Компоненты Control Plane

##### etcd
```
Функция: Распределённое хранилище ключ-значение
Назначение: Хранение всего состояния кластера
- Конфигурации подов
- Секреты
- Сервисы
- ReplicaSets
```
**Критичность**: ✗ Нет etcd = нет кластера

##### kube-apiserver
```
Функция: API сервер Kubernetes
Назначение: Единая точка входа для управления кластером
- REST API для kubectl
- Аутентификация и авторизация
- Валидация объектов
```
**Порт**: 6443

##### kube-controller-manager
```
Функция: Запуск контроллеров
Контроллеры:
- Node Controller: управление узлами
- Replication Controller: репликация подов
- Endpoint Controller: связи сервис-под
- Service Account Controller: учётные записи
```

##### kube-scheduler
```
Функция: Планировщик подов
Алгоритм выбора узла:
1. Фильтрация по resource requests
2. Проверка affinity/anti-affinity
3. Учёт taints и tolerations
4. Scoring (оценка узла)
```

##### kubelet (на Master)
```
Функция: Агент на узле
Обязанности:
- Создание и удаление подов
- Мониторинг контейнеров
- Регистрация узла в кластере
- Health checks (liveness/readiness)
```

##### cri-dockerd
```
Функция: Мост между Docker и Container Runtime Interface
Назначение: Kubernetes 1.24+ не поддерживает Docker напрямую
Конфигурация: /etc/cri-dockerd/config.toml
Сокет: /run/cri-dockerd.sock
```

### 4.2 Worker Nodes

#### 4.2.1 Worker 1
| Параметр | Значение |
|----------|----------|
| **IP** | 192.168.1.75 |
| **Pod CIDR** | 10.244.1.0/24 |
| **Функция** | Выполнение рабочих нагрузок |

**Компоненты:**
- kubelet — агент управления подами
- container runtime — Docker + cri-dockerd
- kube-proxy — сетевое проксирование
- Pods — запущенные контейнеры приложений

#### 4.2.2 Worker 2
| Параметр | Значение |
|----------|----------|
| **IP** | 192.168.1.76 |
| **Pod CIDR** | 10.244.2.0/24 |
| **Функция** | Выполнение рабочих нагрузок |

**Компоненты:**
- kubelet — агент управления подами
- container runtime — Docker + cri-dockerd
- kube-proxy — сетевое проксирование
- Pods — запущенные контейнеры приложений

### 4.3 Сравнение ролей

| Компонент | Control Plane | Worker Node |
|-----------|---------------|-------------|
| etcd | ✓ | ✗ |
| kube-apiserver | ✓ | ✗ |
| kube-scheduler | ✓ | ✗ |
| kube-controller-manager | ✓ | ✗ |
| kubelet | ✓ (опционально) | ✓ |
| kube-proxy | ✗ | ✓ |
| container runtime | ✓ (опционально) | ✓ |
| Пользовательские поды | ✗ | ✓ |

### 4.4 Жизненный цикл пода (Pod Lifecycle)

```
┌─────────────┐
│   PENDING   │  ← Scheduler выбирает узел
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  PULLING     │  ← Скачивание образа
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  CREATING    │  ← Создание контейнера
└──────┬──────┘
       │
       ▼
┌─────────────┐    ┌─────────────────┐
│   RUNNING   │───►│  Liveness Probe │───► RESTART (fail)
└──────┬──────┘    └─────────────────┘
       │
       │◄──────────────────────┐
       │                       │
       ▼                       ▼
┌─────────────┐         ┌─────────────┐
│  READY (1/1)│         │   READY (0/2)│
└──────┬──────┘         └──────┬──────┘
       │                       │
       ▼                       ▼
┌─────────────┐         ┌─────────────┐
│  SERVING    │         │  NOT SERVING│
└─────────────┘         └─────────────┘
```

---

## 5. Развёрнутые сервисы

### 5.1 Namespace: service-system

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: service-system
  labels:
    app: service-system
```

### 5.2 База данных PostgreSQL

#### Deployment: db
```yaml
metadata:
  name: db
  namespace: service-system
spec:
  replicas: 1
  containers:
  - name: postgres
    image: postgres:15-alpine
    ports:
    - containerPort: 5432
    resources:
      requests:
        cpu: 250m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi
```

**Функции:**
- Хранение данных о устройствах
- Хранение истории обслуживания
- Хранение типов услуг
- Обеспечение целостности данных

**Конфигурация:**
| Параметр | Значение |
|----------|----------|
| Database | car_service_db |
| User | postgres |
| Password | postgres |
| Port | 5432 |
| Storage | emptyDir (эфемерное) |

**Схема БД:**

```sql
-- Таблица устройств
CREATE TABLE Devices (
    device_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    model VARCHAR(100),
    purchase_date DATE,
    status VARCHAR(20) DEFAULT 'active'
);

-- Типы услуг
CREATE TABLE Service_Types (
    service_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    recommended_interval_months INT,
    standard_cost DECIMAL(10,2)
);

-- История обслуживания
CREATE TABLE Service_History (
    record_id SERIAL PRIMARY KEY,
    device_id INT REFERENCES Devices(device_id),
    service_id INT REFERENCES Service_Types(service_id),
    service_date DATE NOT NULL,
    cost DECIMAL(10,2),
    notes TEXT,
    next_due_date DATE
);
```

### 5.3 Приложение Service System

#### Deployment: service-system
```yaml
metadata:
  name: service-system
  namespace: service-system
spec:
  replicas: 2
  containers:
  - name: service-system
    image: dmitriier/service-system:latest
    ports:
    - containerPort: 8080
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 500m
        memory: 256Mi
```

**Функции:**
- REST API для управления устройствами
- Управление историей обслуживания
- Справочник типов услуг
- Метрики для Prometheus

**API Endpoints:**

| Метод | Путь | Описание |
|-------|------|----------|
| GET | /api/devices | Получить все устройства |
| POST | /api/devices | Добавить устройство |
| PUT | /api/devices/:id | Обновить устройство |
| DELETE | /api/devices/:id | Удалить устройство |
| GET | /api/services | Типы услуг |
| GET | /api/history | История обслуживания |
| POST | /api/history | Запись обслуживания |
| GET | /metrics | Метрики Prometheus |

### 5.4 Сервисы (Services)

#### Service: db
```yaml
metadata:
  name: db
  namespace: service-system
spec:
  selector:
    app: db
  ports:
  - port: 5432
    targetPort: 5432
  clusterIP: None  # Headless service
```

**Тип**: Headless (без ClusterIP)
**Назначение**: DNS-разрешение для прямого доступа к подам PostgreSQL

#### Service: service-system
```yaml
metadata:
  name: service-system
  namespace: service-system
spec:
  type: ClusterIP
  selector:
    app: service-system
  ports:
  - port: 80
    targetPort: 8080
```

**Тип**: ClusterIP (внутренний)
**Назначение**: Внутренняя балансировка между репликами

#### Service: service-system-service (NodePort)
```yaml
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 8080
    nodePort: 30080
```

**Тип**: NodePort
**Назначение**: Внешний доступ к приложению
**Порт**: 30080

### 5.5 ConfigMap: postgres-init

```yaml
metadata:
  name: postgres-init
  namespace: service-system
```

**Назначение**: Автоматическая инициализация БД при первом запуске

**Содержимое:**
- Создание таблиц
- Начальные данные устройств
- Справочник типов услуг
- Примеры записей истории

---

## 6. Сетевая архитектура

### 6.1 Модель сети Kubernetes

```
┌─────────────────────────────────────────────────────────────────┐
│                        Pod Network                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ service-sys │  │ service-sys │  │     db      │             │
│  │   pod-1     │  │   pod-2     │  │    pod      │             │
│  │ 10.244.x.10 │  │ 10.244.x.11 │  │ 10.244.x.20 │             │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘             │
│         │                │                │                     │
│         └────────────────┼────────────────┘                     │
│                          │                                      │
│                    kube-proxy                                   │
│                          │                                      │
├──────────────────────────┼──────────────────────────────────────┤
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Service Network                       │   │
│  │  ┌─────────────────┐  ┌─────────────────┐               │   │
│  │  │ service-system  │  │       db        │               │   │
│  │  │  10.96.xx.xx    │  │  10.96.xx.xx    │               │   │
│  │  └─────────────────┘  └─────────────────┘               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                          │                                      │
│         ┌────────────────┼────────────────┐                    │
│         ▼                ▼                ▼                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │
│  │  Worker 1   │  │  Worker 2   │  │  External   │            │
│  │ 192.168.1.75│  │ 192.168.1.76│  │   Clients   │            │
│  └─────────────┘  └─────────────┘  └─────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### 6.2 Сетевые политики

#### Входящий трафик

| Источник | Назначение | Порт | Разрешён |
|----------|------------|------|----------|
| External | service-system | 30080 | ✓ NodePort |
| service-system | db | 5432 | ✓ |
| kube-dns | Все поды | 53 | ✓ DNS |

#### Исходящий трафик

| Источник | Назначение | Порт | Разрешён |
|----------|------------|------|----------|
| db | Внешние репозитории | 443 | Pull images |
| service-system | db | 5432 | БД |

### 6.3 DNS в Kubernetes

```bash
# Внутри кластера
db.service-system.svc.cluster.local  →  IP сервиса db
service-system.service-system.svc.cluster.local  →  IP сервиса

# Короткие имена (внутри namespace)
db → service-system.db.svc.cluster.local
```

---

## 7. Система мониторинга

### 7.1 Компоненты мониторинга

```
┌─────────────────────────────────────────────────────────────────┐
│                    Система мониторинга                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌────────────────┐     ┌────────────────┐     ┌───────────┐  │
│   │   Prometheus   │     │     Loki       │     │  Grafana  │  │
│   │  (Метрики)     │     │    (Логи)      │     │ (UI)      │  │
│   └───────┬────────┘     └───────┬────────┘     └─────┬─────┘  │
│           │                      │                    │        │
│           │                      │                    │        │
│   ┌───────▼────────┐     ┌───────▼────────┐    ┌─────▼─────┐  │
│   │ service-system │     │   Promtail     │    │ Dashboards│  │
│   │   /metrics     │     │   (агент)      │    │ + Alerts  │  │
│   └────────────────┘     └────────────────┘    └───────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Метрики приложения

#### HTTP Requests
| Метрика | Тип | Описание |
|---------|-----|----------|
| `http_requests_total` | Counter | Общее количество запросов |
| `http_request_duration_seconds` | Histogram | Время ответа |

#### Database Operations
| Метрика | Тип | Описание |
|---------|-----|----------|
| `db_operations_total` | Counter | Операции с БД |

#### Authentication
| Метрика | Тип | Описание |
|---------|-----|----------|
| `auth_attempts_total` | Counter | Попытки авторизации |
| `auth_failures_total` | Counter | Неудачные попытки |

### 7.3 Примеры PromQL запросов

```promql
-- RPS (запросов в секунду)
sum(rate(http_requests_total[5m]))

-- Среднее время ответа
avg(rate(http_request_duration_seconds_sum[5m]) 
    / rate(http_request_duration_seconds_count[5m]))

-- 95-й перцентиль
histogram_quantile(0.95, rate(http_request_duration_seconds[5m]))

-- Ошибки 5xx
sum(rate(http_requests_total{status=~"5.."}[5m]))

-- Успешность БД
sum(db_operations_total{success="true"}) / sum(db_operations_total) * 100
```

### 7.4 Алерты

| Alert | Условие | Severity |
|-------|---------|----------|
| HighErrorRate | >5% ошибок 5xx | critical |
| SlowResponses | p95 > 1s | warning |
| ManyAuthFailures | >0.1 fail/s | warning |
| DatabaseErrors | >0.01 errors/s | critical |
| ServiceDown | up == 0 | critical |

---

## 8. Безопасность и рекомендации

### 8.1 Текущее состояние безопасности

| Аспект | Состояние | Рекомендация |
|--------|-----------|--------------|
| Secrets | В plain text | Использовать Kubernetes Secrets |
| Network Policies | Не настроены | Добавить политики |
| RBAC | Базовый | Расширить роли |
| TLS | Внутри кластера | Настроить TLS termination |
| Image Security | Базовые образы | Сканировать на уязвимости |

### 8.2 Рекомендации по улучшению

#### 8.2.1 Secrets Management
```yaml
# Вместо:
env:
- name: DB_PASSWORD
  value: "postgres"

# Использовать:
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-secrets
      key: password
```

#### 8.2.2 Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: service-system
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-db
  namespace: service-system
spec:
  podSelector:
    matchLabels:
      app: db
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: service-system
    ports:
    - protocol: TCP
      port: 5432
```

#### 8.2.3 Resource Limits
Текущие настройки адекватны для нагрузки, но рекомендуется:
- Мониторить реальное использование
- Корректировать лимиты по метрикам

### 8.3 Резервное копирование

```bash
# Backup etcd (Control Plane)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Backup PostgreSQL
kubectl exec deployment/db -- pg_dump -U postgres car_service_db > backup.sql
```

---

## 9. Обслуживание и эксплуатация

### 9.1 Команды мониторинга

```bash
# Статус подов
kubectl get pods -o wide -n service-system

# Статус нод
kubectl get nodes

# Логи приложения
kubectl logs -l app=service-system -n service-system --tail=50

# Логи БД
kubectl logs deployment/db -n service-system --tail=20

# Events
kubectl get events -n service-system --sort-by='.lastTimestamp'

# Ресурсы
kubectl top pods -n service-system
kubectl top nodes
```

### 9.2 Операции обновления

```bash
# Rolling update приложения
kubectl set image deployment/service-system \
  service-system=dmitriier/service-system:latest \
  -n service-system

# Откат при проблемах
kubectl rollout undo deployment/service-system -n service-system

# Статус rollout
kubectl rollout status deployment/service-system -n service-system
```

### 9.3 Масштабирование

```bash
# Горизонтальное масштабирование
kubectl scale deployment service-system \
  --replicas=4 -n service-system

# Autoscaling (если настроен HPA)
kubectl get hpa -n service-system
```

### 9.4 Troubleshooting

| Проблема | Решение |
|----------|---------|
| Под не запускается | `kubectl describe pod <name>` |
| Ошибка БД | `kubectl logs deployment/db` |
| Под не видит БД | Проверить DNS: `kubectl exec <pod> -- nslookup db` |
| High CPU/Memory | `kubectl top pods`, скорректировать лимиты |
| Network issues | Проверить kube-proxy: `kubectl logs -l k8s-app=kube-proxy` |

### 9.5 Checklist обслуживания

#### Ежедневно
- [ ] Проверить статус подов
- [ ] Проверить алерты
- [ ] Проверить логи на ошибки

#### Еженедельно
- [ ] Проверить использование ресурсов
- [ ] Проанализировать метрики
- [ ] Проверить обновления образов

#### Ежемесячно
- [ ] Ротация secrets
- [ ] Резервное копирование etcd
- [ ] Тестовый failover
- [ ] Обновление безопасности

---

## Заключение

Данный Kubernetes кластер представляет собой полностью функциональную платформу для развёртывания и управления Service Management System. Кластер состоит из:

1. **Control Plane** (192.168.1.74) — управляет состоянием кластера
2. **Worker 1** (192.168.1.75) — выполняет рабочие нагрузки
3. **Worker 2** (192.168.1.76) — выполняет рабочие нагрузки

Основные характеристики:
- Высокая доступность (2 реплики приложения)
- Изоляция через namespace
- Мониторинг и логирование
- Автоматическое восстановление
- Масштабируемость

Для дальнейшего улучшения рекомендуется:
1. Внедрить Kubernetes Secrets для хранения паролей
2. Настроить Network Policies
3. Добавить постоянное хранилище для БД
4. Настроить автоматическое масштабирование (HPA)
5. Внедрить GitOps практики (ArgoCD/Flux)

---

**Дата создания отчёта**: 2026-01-12  
**Автор**: System Administrator  
**Версия**: 1.0

