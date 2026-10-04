#!/usr/bin/env bash
set -euo pipefail
kubectl delete namespace "lab-01-01" --ignore-not-found --wait=true
kubectl config set-context --current --namespace=default >/dev/null
echo "Namespace lab-01-01 удалён"
