#!/usr/bin/env bash
# Удалить учебный кластер целиком.
set -euo pipefail
cd "$(dirname "$0")"
./cloud-provider-kind.sh stop
kind delete cluster --name k8s-course
