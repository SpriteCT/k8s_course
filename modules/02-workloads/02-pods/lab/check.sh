#!/usr/bin/env bash
# Автопроверка лабы. Проверяет состояние кластера. Код выхода 0 — всё пройдено.
set -uo pipefail
NS="lab-02-02"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }
answer() { jp configmap/answers "{.data.$1}" | tr -d '[:space:]'; }
ready() { jp pod/"$1" '{.status.conditions[?(@.type=="Ready")].status}'; }

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с «Подготовки»"; exit 1; }

echo "Задание 1. Подготовка init-контейнером"
if ! kubectl -n "$NS" get pod web >/dev/null 2>&1; then
  fail "pod web не найден" "kubectl apply -f solution/web.yaml"
elif [ "$(ready web)" != "True" ]; then
  fail "pod web не готов" "kubectl -n $NS describe pod web; проверьте init-контейнер"
else
  ip=$(jp pod/web '{.status.podIP}')
  body=$(kubectl -n "$NS" run check-$RANDOM --rm -i --restart=Never --quiet --image=busybox:1.36 -- \
    wget -qO- -T5 "http://$ip" 2>/dev/null)
  if echo "$body" | grep -q 'from init'; then ok "web отдаёт страницу, записанную init-контейнером"
  else fail "web не отдаёт 'from init' (получено: '${body:0:40}')" "init-контейнер должен писать index.html в общий том"; fi
fi

echo "Задание 2. Downward API"
if ! kubectl -n "$NS" get pod info >/dev/null 2>&1; then
  fail "pod info не найден" "kubectl apply -f solution/info.yaml"
else
  envref=$(jp pod/info '{.spec.containers[0].env[?(@.name=="MY_NODE")].valueFrom.fieldRef.fieldPath}')
  node=$(jp pod/info '{.spec.nodeName}')
  if [ "$envref" != "spec.nodeName" ]; then fail "у info нет env MY_NODE из spec.nodeName (сейчас fieldPath='$envref')"
  else ok "info: MY_NODE проброшен через Downward API (spec.nodeName)"; fi
  if ! kubectl -n "$NS" get configmap answers >/dev/null 2>&1; then fail "ConfigMap answers не найден"
  else
    got=$(answer node)
    [ -n "$node" ] && [ "$got" = "$node" ] && ok "node: $got" || fail "node: записано '$got', узел info — '$node'"
  fi
fi

echo "Задание 3. Починить init-контейнер"
if ! kubectl -n "$NS" get pod fixme >/dev/null 2>&1; then
  fail "pod fixme не найден" "kubectl apply -f start/broken.yaml и почините init"
elif [ "$(ready fixme)" != "True" ]; then
  reason=$(jp pod/fixme '{.status.initContainerStatuses[0].state.waiting.reason}')
  fail "pod fixme не готов${reason:+ (init: $reason)}" "kubectl -n $NS logs fixme -c setup — исправьте команду init"
else
  ok "pod fixme готов — init-контейнер успешно отработал"
fi

echo "Задание 4. Нативный sidecar"
if ! kubectl -n "$NS" get pod withcar >/dev/null 2>&1; then
  fail "pod withcar не найден" "kubectl apply -f solution/withcar.yaml"
else
  rp=$(jp pod/withcar '{.spec.initContainers[?(@.name=="logger")].restartPolicy}')
  runningst=$(jp pod/withcar '{.status.initContainerStatuses[?(@.name=="logger")].state.running}')
  if [ "$rp" != "Always" ]; then fail "sidecar logger не нативный: restartPolicy='$rp', нужно Always" "объявите logger в initContainers с restartPolicy: Always"
  elif [ -z "$runningst" ]; then fail "sidecar logger не работает (нет state.running)" "kubectl -n $NS get pod withcar"
  elif [ "$(ready withcar)" != "True" ]; then fail "pod withcar не готов" "kubectl -n $NS describe pod withcar"
  else ok "withcar: нативный sidecar logger работает, pod Ready"; fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
