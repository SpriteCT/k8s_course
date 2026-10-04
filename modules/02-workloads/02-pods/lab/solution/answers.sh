#!/usr/bin/env bash
# Задание 2: записать имя узла pod info в ConfigMap answers.
set -euo pipefail
NS=lab-02-02
node=$(kubectl -n "$NS" get pod info -o jsonpath='{.spec.nodeName}')
kubectl -n "$NS" create configmap answers \
  --from-literal=node="$node" \
  --dry-run=client -o yaml | kubectl apply -f -
