#!/usr/bin/env bash
# Задание 1: собрать ответы из живого кластера и записать их в ConfigMap answers.
set -euo pipefail
NS=lab-01-01
api=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
etcd_node=$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].spec.nodeName}')
proxies=$(kubectl -n kube-system get pods -l k8s-app=kube-proxy --no-headers | wc -l)
runtime=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}')

kubectl -n "$NS" create configmap answers \
  --from-literal=api-server="$api" \
  --from-literal=etcd-node="$etcd_node" \
  --from-literal=kube-proxy-pods="$proxies" \
  --from-literal=container-runtime="${runtime%%://*}" \
  --from-literal=recreated-by=kube-controller-manager \
  --dry-run=client -o yaml | kubectl apply -f -
