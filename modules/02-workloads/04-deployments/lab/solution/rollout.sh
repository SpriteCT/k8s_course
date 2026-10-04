#!/usr/bin/env bash
# Задание 2: выкат нового образа и откат обратно.
set -euo pipefail
NS=lab-02-04
kubectl -n "$NS" set image deployment/web web=nginx:1.26-alpine
kubectl -n "$NS" rollout status deployment/web --timeout=120s
kubectl -n "$NS" rollout undo deployment/web
kubectl -n "$NS" rollout status deployment/web --timeout=120s
kubectl -n "$NS" get deployment web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'  # nginx:1.27-alpine
