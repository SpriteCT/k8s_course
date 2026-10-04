#!/usr/bin/env bash
# Задание 4: собрать ответы из Docker и записать их в ConfigMap answers.
set -euo pipefail
NS=lab-00-01
CP=k8s-course-control-plane

# 6443/tcp -> 127.0.0.1:40625  →  40625
api_port=$(docker port "$CP" 6443/tcp | head -1 | awk -F: '{print $NF}')
containers=$(docker ps -q --filter label=io.x-k8s.kind.cluster=k8s-course | wc -l)
image=$(docker inspect -f '{{.Config.Image}}' "$CP")
ingress_port=$(docker port "$CP" 80/tcp | head -1 | awk -F: '{print $NF}')

kubectl -n "$NS" create configmap answers \
  --from-literal=api-port="$api_port" \
  --from-literal=node-containers="$containers" \
  --from-literal=node-image="${image%%@*}" \
  --from-literal=ingress-host-port="$ingress_port" \
  --dry-run=client -o yaml | kubectl apply -f -
