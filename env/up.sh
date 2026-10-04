#!/usr/bin/env bash
# Поднять учебный кластер. Повторный запуск безопасен.
set -euo pipefail
cd "$(dirname "$0")"

for bin in docker kind kubectl; do
  command -v "$bin" >/dev/null || { echo "Не найден $bin — установите его (см. урок 00-setup/01-environment)"; exit 1; }
done

if kind get clusters | grep -qx k8s-course; then
  echo "Кластер k8s-course уже существует"
else
  kind create cluster --config kind-config.yaml
fi

kubectl config use-context kind-k8s-course
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes -o wide
