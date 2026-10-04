#!/usr/bin/env bash
# Автопроверка лабы. Проверяет состояние кластера. Код выхода 0 — всё пройдено.
set -uo pipefail
NS="lab-02-01"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }
answer() { jp configmap/answers "{.data.$1}" | tr -d '[:space:]'; }
# число контейнеров pod
ccount() { jp pod/"$1" '{range .spec.containers[*]}{.name}{"\n"}{end}' | grep -c .; }
ready() { jp pod/"$1" '{.status.conditions[?(@.type=="Ready")].status}'; }

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с «Подготовки»"; exit 1; }

echo "Задание 1. Два контейнера в одном pod"
if ! kubectl -n "$NS" get pod shared >/dev/null 2>&1; then
  fail "pod shared не найден" "kubectl apply -f solution/shared.yaml"
else
  n=$(ccount shared); r=$(ready shared)
  simg=$(jp pod/shared '{.spec.containers[?(@.name=="server")].image}')
  if [ "$n" != "2" ]; then fail "в pod shared $n контейнер(ов), нужно 2"
  elif [ "$simg" != "nginx:1.27-alpine" ]; then fail "контейнер server: образ '$simg', ожидался nginx:1.27-alpine"
  elif [ "$r" != "True" ]; then fail "pod shared не готов (Ready!=True)" "kubectl -n $NS get pod shared; kubectl -n $NS logs shared -c client"
  else ok "pod shared: 2 контейнера, Running 2/2"; fi
fi

echo "Задание 2. Общая сеть и факты"
if ! kubectl -n "$NS" get configmap answers >/dev/null 2>&1; then
  fail "ConfigMap answers не найден"
else
  got=$(answer containers)
  [ "$got" = "2" ] && ok "containers: 2" || fail "containers: '$got', ожидалось 2"
  want=$(jp pod/shared '{.status.podIP}'); got=$(answer pod-ip)
  [ -n "$want" ] && [ "$got" = "$want" ] && ok "pod-ip: $got" || fail "pod-ip: '$got', ожидался '$want'" "kubectl get pod shared -o jsonpath='{.status.podIP}'"
fi

echo "Задание 3. Один pod вместо двух"
if ! kubectl -n "$NS" get pod paired >/dev/null 2>&1; then
  fail "pod paired не найден" "соберите два контейнера в один pod paired"
elif [ "$(ccount paired)" != "2" ]; then
  fail "в pod paired $(ccount paired) контейнер(ов), нужно 2" "server + client в одном pod"
elif [ "$(ready paired)" != "True" ]; then
  fail "pod paired не готов" "kubectl -n $NS get pod paired"
else
  body=$(kubectl -n "$NS" exec paired -c client -- wget -qO- -T5 http://localhost 2>/dev/null)
  if echo "$body" | grep -qi nginx; then ok "в pod paired client достаёт server по localhost"
  else fail "client в paired не достучался до server по localhost" "оба контейнера должны быть в ОДНОМ pod"; fi
fi

echo "Задание 4. Урезать права"
if ! kubectl -n "$NS" get pod dropped >/dev/null 2>&1; then
  fail "pod dropped не найден" "kubectl apply -f solution/dropped.yaml"
else
  drop=$(jp pod/dropped '{.spec.containers[0].securityContext.capabilities.drop}')
  phase=$(jp pod/dropped '{.status.phase}')
  if ! echo "$drop" | grep -q 'ALL'; then fail "у контейнера не отобраны все capabilities (drop сейчас: '$drop')" "securityContext.capabilities.drop: [\"ALL\"]"
  elif [ "$phase" != "Running" ]; then fail "pod dropped в фазе $phase, ожидалась Running" "kubectl -n $NS describe pod dropped"
  else ok "pod dropped работает с drop: [ALL]"; fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
