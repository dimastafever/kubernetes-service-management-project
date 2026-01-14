# Kubernetes 1.24+ с Docker - Решение установки cri-dockerd

## Анализ проблемы

Ошибка `dial tcp [::1]:10248: connect: connection refused` возникает из-за:
- Kubernetes 1.24+ удалил встроенную поддержку Docker
- Docker по умолчанию не предоставляет конечную точку CRI (Container Runtime Interface)
- Вам нужен **cri-dockerd** для моста Docker к CRI

## Решение - Шаг за шагом

### Шаг 1: Установите cri-dockerd

**Вариант A: Используйте существующий пакет (Рекомендуется)**
```bash
cd /home/adminstd/Desktop
sudo dpkg -i cri-dockerd_0.3.1.3-0.ubuntu-jammy_amd64.deb
sudo apt-get install -f -y  # Исправить любые проблемы с зависимостями
```

**Вариант B: Если установка пакета не удалась, скачайте с GitHub**
```bash
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1/cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb
sudo dpkg -i cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb
sudo apt-get install -f -y
```

### Шаг 2: Настройте cri-dockerd

```bash
# Создать каталог конфигурации
sudo mkdir -p /etc/cri-dockerd

# Создать конфигурацию cri-dockerd
sudo bash -c 'cat > /etc/cri-dockerd/config.toml << EOF
[grpc]
  address = "/run/cri-dockerd.sock"
[cri_socket]
  docker_endpoint = "unix:///var/run/docker.sock"
EOF'
```

### Шаг 3: Настройте kubelet для использования cri-dockerd

```bash
# Создать переопределение kubelet
sudo mkdir -p /etc/systemd/system/kubelet.service.d/
sudo bash -c 'cat > /etc/systemd/system/kubelet.service.d/20-cri-dockerd.conf << EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/cri-dockerd.sock"
EOF'
```

### Шаг 4: Включите и запустите cri-dockerd

```bash
sudo systemctl daemon-reload
sudo systemctl enable cri-dockerd
sudo systemctl start cri-dockerd
```

### Шаг 5: Проверьте, что cri-dockerd работает

```bash
sudo systemctl status cri-dockerd
```

Ожидаемый вывод должен показать `active (running)`.

### Шаг 6: Перезапустите kubelet

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

### Шаг 7: Проверьте настройку

```bash
# Проверить здоровье kubelet
curl -sSL http://localhost:10248/healthz
```

Ожидаемый вывод: `ok`

## Полное решение одной командой

Запустите все команды сразу:

```bash
# Установить cri-dockerd
cd /home/adminstd/Desktop
sudo dpkg -i cri-dockerd_0.3.1.3-0.ubuntu-jammy_amd64.deb 2>/dev/null || \
wget -q https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.1/cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb && \
sudo dpkg -i cri-dockerd_0.3.1-0.ubuntu-jammy_amd64.deb
sudo apt-get install -f -y

# Настроить cri-dockerd
sudo mkdir -p /etc/cri-dockerd
sudo bash -c 'cat > /etc/cri-dockerd/config.toml << EOF
[grpc]
  address = "/run/cri-dockerd.sock"
[cri_socket]
  docker_endpoint = "unix:///var/run/docker.sock"
EOF'

# Настроить kubelet
sudo mkdir -p /etc/systemd/system/kubelet.service.d/
sudo bash -c 'cat > /etc/systemd/system/kubelet.service.d/20-cri-dockerd.conf << EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/cri-dockerd.sock"
EOF'

# Запустить сервисы
sudo systemctl daemon-reload
sudo systemctl enable cri-dockerd
sudo systemctl start cri-dockerd
sudo systemctl restart kubelet

# Проверить
sleep 5
curl -sSL http://localhost:10248/healthz
```

## Устранение неполадок

Если вы все еще сталкиваетесь с проблемами:

1. **Проверьте статус cri-dockerd:**
   ```bash
   sudo systemctl status cri-dockerd
   ```

2. **Проверьте логи kubelet:**
   ```bash
   sudo journalctl -u kubelet -n 50 --no-pager
   ```

3. **Проверьте логи cri-dockerd:**
   ```bash
   sudo journalctl -u cri-dockerd -n 50 --no-pager
   ```

4. **Проверьте, существует ли сокет:**
   ```bash
   ls -la /run/cri-dockerd.sock
   ```

## После установки

После успешной установки вы можете повторить kubeadm init:

```bash
sudo /usr/local/bin/kubeadm init --config /etc/kubernetes/kubeadm-config.yaml --ignore-preflight-errors=all
```

