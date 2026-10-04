#!/usr/bin/env bash
# Подготовить Linux-VM (Ubuntu 24.04 или Debian 12/13, x86_64) для курса: Docker, kind, kubectl, k9s.
# Запускать внутри VM от обычного пользователя с sudo. Повторный запуск безопасен.
set -euo pipefail

if ! command -v sudo >/dev/null; then
  echo "Нет sudo. Под root выполните: apt install -y sudo && usermod -aG sudo $USER — и перелогиньтесь"
  exit 1
fi
# В минимальной установке Debian может не быть curl
if ! command -v curl >/dev/null; then
  sudo apt-get update && sudo apt-get install -y curl ca-certificates
fi

KIND_VERSION=v0.33.0      # должна совпадать с образами в env/kind-config.yaml
KUBECTL_VERSION=v1.37.1   # ±1 minor от версии кластера (v1.37)
ARCH=amd64

need_relogin=0

# --- Docker Engine ---
if ! command -v docker >/dev/null; then
  echo ">>> Устанавливаю Docker Engine"
  curl -fsSL https://get.docker.com | sudo sh
fi
if ! id -nG "$USER" | grep -qw docker; then
  sudo usermod -aG docker "$USER"
  need_relogin=1
fi

# --- kind ---
if [[ "$(kind version 2>/dev/null | awk '{print $2}')" != "$KIND_VERSION" ]]; then
  echo ">>> Устанавливаю kind $KIND_VERSION"
  curl -fsSLo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  sudo install -m 0755 /tmp/kind /usr/local/bin/kind
fi

# --- kubectl ---
if ! kubectl version --client 2>/dev/null | grep -q "$KUBECTL_VERSION"; then
  echo ">>> Устанавливаю kubectl $KUBECTL_VERSION"
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
fi

# --- k9s (необязательный терминальный UI) ---
if ! command -v k9s >/dev/null; then
  echo ">>> Устанавливаю k9s"
  curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_${ARCH}.tar.gz" \
    | sudo tar -xz -C /usr/local/bin k9s
fi

# --- лимиты inotify: без них в многоузловом kind падают pod с "too many open files" ---
sudo tee /etc/sysctl.d/99-kind.conf >/dev/null <<'EOF'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF
sudo sysctl --system >/dev/null

# --- автодополнение kubectl и короткий алиас k ---
if ! grep -q 'kubectl completion bash' ~/.bashrc; then
  cat >> ~/.bashrc <<'EOF'
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
EOF
fi

echo
docker --version
kind version
kubectl version --client | head -1
echo
if (( need_relogin )); then
  echo "Готово. Перелогиньтесь в VM (exit и снова ssh), чтобы группа docker применилась, затем: ./env/up.sh"
else
  echo "Готово. Поднимайте кластер: ./env/up.sh"
fi
