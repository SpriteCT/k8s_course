#!/usr/bin/env bash
set -euo pipefail
kubectl delete namespace "lab-02-06" --ignore-not-found --wait=true
kubectl config set-context --current --namespace=default >/dev/null
echo "Namespace lab-02-06 удалён"
