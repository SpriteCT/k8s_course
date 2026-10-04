#!/usr/bin/env bash
# Задание 2: контекст lab-00-01 на основе kind-k8s-course и pod hello в нём.
set -euo pipefail
kubectl config set-context lab-00-01 \
  --cluster=kind-k8s-course --user=kind-k8s-course --namespace=lab-00-01
kubectl config use-context lab-00-01
kubectl get pod hello >/dev/null 2>&1 || kubectl run hello --image=nginx:1.27-alpine
kubectl wait --for=condition=Ready pod/hello --timeout=120s
