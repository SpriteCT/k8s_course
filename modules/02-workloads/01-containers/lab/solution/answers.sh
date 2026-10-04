#!/usr/bin/env bash
# Задание 2: факты про pod shared.
set -euo pipefail
NS=lab-02-01
n=$(kubectl -n "$NS" get pod shared -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}{end}' | grep -c .)
ip=$(kubectl -n "$NS" get pod shared -o jsonpath='{.status.podIP}')
kubectl -n "$NS" create configmap answers \
  --from-literal=containers="$n" \
  --from-literal=pod-ip="$ip" \
  --dry-run=client -o yaml | kubectl apply -f -
