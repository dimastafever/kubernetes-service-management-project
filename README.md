# Проект Kubernetes Service Management

Этот репозиторий содержит проект системы управления обслуживанием компьютерного оборудования, развернутой в Kubernetes кластере с использованием Ansible для автоматизации.

## Описание проекта

**Система управления обслуживанием (Service Management System)** — это комплексное решение для управления обслуживанием компьютерного оборудования. Система предоставляет:

- Отслеживание устройств (принтеры, серверы, роутеры, рабочие станции, ИБП)
- Управление типами обслуживания (замена тонера, чистка, обновление прошивки)
- История обслуживания с автоматическим расчетом следующей даты обслуживания
- REST API для интеграции с другими системами
- Веб-интерфейс для управления
- Метрики Prometheus для мониторинга производительности
- Дашборды Grafana для визуализации данных
- Централизованное логирование с Loki

## Архитектура

```
+-------------------------------------------------------------------------+
|                           Service Management System                      |
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

## Быстрый старт

### Предварительные требования

- Kubernetes кластер (1.24+)
- kubectl настроен
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

## Структура репозитория

- `COMPREHENSIVE_GUIDE.md`: Подробное руководство по настройке Kubernetes кластера и развертыванию системы
- `cri-dockerd_solution.md`: Решение для установки cri-dockerd в Kubernetes 1.24+
- `KUBERNETES_CLUSTER_REPORT.md`: Отчет о статусе Kubernetes кластера
- `deployment.yaml`: Kubernetes манифесты для развертывания
- `namespace.yaml`: Определение namespace
- `postgres.yaml`: Конфигурация PostgreSQL
- `ansible.cfg`: Конфигурация Ansible
- `playbook.yml`: Ansible playbook для автоматизации
- `inventory.ini`: Инвентарь Ansible
- `roles/`: Роли Ansible (DNS и др.)
- Скрипты настройки: `kubernetes_setup.sh`, `check_kubernetes_setup.sh`, `setup_worker2.sh`, etc.

## Настройка кластера

Для настройки Kubernetes кластера следуйте инструкциям в `COMPREHENSIVE_GUIDE.md`. Кратко:

1. Установите Kubernetes компоненты на Control Plane
2. Настройте cri-dockerd для совместимости с Docker
3. Инициализируйте кластер
4. Добавьте Worker nodes
5. Разверните сетевой плагин (Flannel)

Используйте Ansible playbook для автоматизации процесса.

## API Endpoints

| Метод | Endpoint | Описание |
|--------|----------|-------------|
| GET | `/api/devices` | Получить все устройства |
| POST | `/api/devices` | Добавить устройство |
| PUT | `/api/devices/<id>` | Обновить устройство |
| DELETE | `/api/devices/<id>` | Удалить устройство |
| GET | `/api/service-types` | Получить типы обслуживания |
| POST | `/api/service-types` | Добавить тип обслуживания |
| GET | `/api/service-history` | Получить историю обслуживания |
| POST | `/api/service-history` | Добавить запись обслуживания |
| GET | `/metrics` | Метрики Prometheus |

## Мониторинг

- **Prometheus**: Сбор метрик приложения
- **Grafana**: Дашборды для визуализации
- **Loki**: Централизованное логирование

## Источники  

[Как развернуть и управлять Kubernetes](https://serverspace.ru/support/help/kak-razvernut-i-upravlyat-kubernetes/?utm_source=google.com&utm_medium=organic&utm_campaign=google.com&utm_referrer=google.com)

[Основной репозиторий, позже сделаю клон](https://github.com/SermerL2/computer_service_system)