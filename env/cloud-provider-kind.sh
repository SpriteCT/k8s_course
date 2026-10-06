#!/usr/bin/env bash
# Локальная замена облачного балансировщика для Service type=LoadBalancer (урок 02-05).
# Запускает cloud-provider-kind контейнером в сети kind. Повторный запуск безопасен.
#   ./env/cloud-provider-kind.sh        — запустить
#   ./env/cloud-provider-kind.sh stop   — остановить и удалить
set -euo pipefail

NAME=cloud-provider-kind
IMAGE=registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.12.0

if [ "${1:-}" = "stop" ]; then
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  echo "$NAME остановлен"
  exit 0
fi

kind get clusters | grep -qx k8s-course || { echo "Кластер k8s-course не найден — сначала ./env/up.sh"; exit 1; }

if [ "$(docker inspect -f '{{.State.Running}}' "$NAME" 2>/dev/null)" = "true" ]; then
  echo "$NAME уже запущен"
else
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  # Контейнеру нужен docker.sock: балансировщик для каждого Service он поднимает отдельным контейнером.
  docker run -d --name "$NAME" --restart unless-stopped --network kind \
    -v /var/run/docker.sock:/var/run/docker.sock "$IMAGE" >/dev/null
  echo "$NAME запущен ($IMAGE)"
fi
