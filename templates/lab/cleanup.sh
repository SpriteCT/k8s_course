#!/usr/bin/env bash
set -euo pipefail
kubectl delete namespace "lab-{{NS}}" --ignore-not-found --wait=true
kubectl config set-context --current --namespace=default >/dev/null
echo "Namespace lab-{{NS}} удалён"
