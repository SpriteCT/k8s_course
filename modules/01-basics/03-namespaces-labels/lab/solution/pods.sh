#!/usr/bin/env bash
# Задания 1, 2, 4: pod'ы с метками, ответы, аннотация.
set -euo pipefail
NS=lab-01-03
kubectl -n "$NS" run web-1  --image=nginx:1.27-alpine -l app=shop,tier=frontend,env=prod
kubectl -n "$NS" run web-2  --image=nginx:1.27-alpine -l app=shop,tier=frontend,env=dev
kubectl -n "$NS" run api-1  --image=nginx:1.27-alpine -l app=shop,tier=api,env=prod
kubectl -n "$NS" run cache-1 --image=nginx:1.27-alpine -l app=shop,tier=cache
kubectl -n "$NS" wait --for=condition=Ready pod --all --timeout=120s

frontend=$(kubectl -n "$NS" get pods -l app=shop,tier=frontend --no-headers | wc -l | tr -d ' ')
prod=$(kubectl -n "$NS" get pods -l app=shop,env=prod --no-headers | wc -l | tr -d ' ')
noenv=$(kubectl -n "$NS" get pods -l 'app=shop,!env' --no-headers | wc -l | tr -d ' ')

kubectl -n "$NS" create configmap answers \
  --from-literal=frontend-count="$frontend" \
  --from-literal=prod-count="$prod" \
  --from-literal=no-env-count="$noenv" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" annotate pod api-1 owner=team-shop --overwrite
