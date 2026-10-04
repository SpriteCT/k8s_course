#!/usr/bin/env bash
set -euo pipefail
NS="lab-02-03"
kubectl delete namespace "$NS" --ignore-not-found --wait=true
for ctx in $(kubectl config view -o jsonpath="{range .contexts[?(@.context.namespace==\"$NS\")]}{.name}{\"\n\"}{end}"); do
  kubectl config set-context "$ctx" --namespace=default >/dev/null
  echo "Контекст $ctx: namespace по умолчанию возвращён в default"
done
echo "Namespace $NS удалён"
