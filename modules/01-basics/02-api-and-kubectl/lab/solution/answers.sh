#!/usr/bin/env bash
# Задание 2: собрать ответы про pod web и записать в ConfigMap answers.
set -euo pipefail
NS=lab-01-02
node=$(kubectl -n "$NS" get pod web -o jsonpath='{.spec.nodeName}')
image=$(kubectl -n "$NS" get pod web -o jsonpath='{.spec.containers[0].image}')
apiver=$(kubectl -n "$NS" get pod web -o jsonpath='{.apiVersion}')

kubectl -n "$NS" create configmap answers \
  --from-literal=api-version="$apiver" \
  --from-literal=pod-node="$node" \
  --from-literal=image="$image" \
  --from-literal=raw-path="/api/v1/namespaces/$NS/pods/web" \
  --dry-run=client -o yaml | kubectl apply -f -
