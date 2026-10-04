#!/usr/bin/env bash
# Удалить учебный кластер целиком.
set -euo pipefail
kind delete cluster --name k8s-course
