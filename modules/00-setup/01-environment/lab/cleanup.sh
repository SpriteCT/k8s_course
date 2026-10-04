#!/usr/bin/env bash
set -euo pipefail
kubectl delete namespace "lab-00-01" --ignore-not-found --wait=true
# Вернуть основной контекст и убрать созданный в задании 2
kubectl config use-context kind-k8s-course >/dev/null
if kubectl config get-contexts -o name | grep -qx lab-00-01; then
  kubectl config delete-context lab-00-01 >/dev/null
fi
echo "Namespace lab-00-01 и контекст lab-00-01 удалены, текущий контекст: kind-k8s-course"
echo "Если задавали KUBECONFIG в задании 3: unset KUBECONFIG"
