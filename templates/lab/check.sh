#!/usr/bin/env bash
# Автопроверка лабы. Ничего не меняет в кластере (кроме временных pod-проверок).
# Код выхода 0 — все задания выполнены.
set -uo pipefail
NS="lab-{{NS}}"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }

# Значение поля ресурса или пустая строка
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }

# HTTP-запрос изнутри кластера (временный pod удаляется сам)
in_cluster_curl() {
  kubectl -n "$NS" run "check-$RANDOM" --rm -i --restart=Never --quiet \
    --image=busybox:1.36 -- wget -qO- -T 5 "$1" 2>/dev/null
}

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с раздела «Подготовка»"; exit 1; }

echo "Задание 1"
replicas=$(jp deployment/web '{.status.readyReplicas}')
if [ "${replicas:-0}" = "3" ]; then ok "Deployment web: 3 готовые реплики"
else fail "Deployment web: ожидалось 3 готовые реплики, сейчас ${replicas:-0}" "kubectl -n $NS describe deploy web"; fi

echo "Задание 2"
# …

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
