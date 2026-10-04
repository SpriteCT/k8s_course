#!/usr/bin/env bash
# Автопроверка лабы. Проверяет состояние кластера. Код выхода 0 — всё пройдено.
set -uo pipefail
NS="lab-01-02"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }
answer() { jp configmap/answers "{.data.$1}" | tr -d '[:space:]'; }

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с раздела «Подготовка»"; exit 1; }

echo "Задание 1. Создать объект декларативно"
if ! kubectl -n "$NS" get pod web >/dev/null 2>&1; then
  fail "pod web не найден" "kubectl apply -f pod.yaml"
else
  image=$(jp pod/web '{.spec.containers[0].image}')
  label=$(jp pod/web '{.metadata.labels.app}')
  port=$(jp pod/web '{.spec.containers[0].ports[0].containerPort}')
  ready=$(jp pod/web '{.status.conditions[?(@.type=="Ready")].status}')
  if [ "$image" != "nginx:1.27-alpine" ]; then fail "pod web: образ '$image', ожидался nginx:1.27-alpine"
  elif [ "$ready" != "True" ]; then fail "pod web не готов (Ready!=True)" "kubectl -n $NS describe pod web"
  elif [ "$label" != "web" ]; then fail "pod web: нет метки app=web (сейчас '$label')"
  elif [ "$port" != "80" ]; then fail "pod web: контейнер не слушает порт 80 (сейчас '$port')"
  else ok "pod web работает: nginx:1.27-alpine, app=web, порт 80"; fi
fi

echo "Задание 2. Достать данные из кластера"
if ! kubectl -n "$NS" get configmap answers >/dev/null 2>&1; then
  fail "ConfigMap answers не найден" "создайте его командой из «Подготовки»"
else
  got=$(answer api-version)
  [ "$got" = "v1" ] && ok "api-version: v1" || fail "api-version: '$got', ожидалось v1" "kubectl get pod web -o jsonpath='{.apiVersion}'"

  want=$(jp pod/web '{.spec.nodeName}'); got=$(answer pod-node)
  [ -n "$want" ] && [ "$got" = "$want" ] && ok "pod-node: $got" || fail "pod-node: '$got', ожидалось '$want'" "kubectl get pod web -o jsonpath='{.spec.nodeName}'"

  got=$(answer image)
  [ "$got" = "nginx:1.27-alpine" ] && ok "image: $got" || fail "image: '$got', ожидалось nginx:1.27-alpine"

  got=$(answer raw-path)
  if [ "$got" = "/api/v1/namespaces/$NS/pods/web" ]; then ok "raw-path: $got"
  else fail "raw-path: '$got'" "core-объект обслуживается под /api/v1/namespaces/$NS/pods/web"; fi
fi

echo "Задание 3. Починить манифест"
if ! kubectl -n "$NS" get pod fixed >/dev/null 2>&1; then
  fail "pod fixed не найден" "kubectl apply -f start/broken.yaml — и почините ошибки"
else
  image=$(jp pod/fixed '{.spec.containers[0].image}')
  ready=$(jp pod/fixed '{.status.conditions[?(@.type=="Ready")].status}')
  if [ "$image" != "nginx:1.27-alpine" ]; then fail "pod fixed: образ '$image', ожидался nginx:1.27-alpine"
  elif [ "$ready" != "True" ]; then fail "pod fixed не готов (Ready!=True)" "kubectl -n $NS describe pod fixed"
  else ok "pod fixed работает на nginx:1.27-alpine"; fi
fi

echo "Задание 4. Доступ без Service"
ip=$(jp pod/web '{.status.podIP}')
if [ -z "$ip" ]; then
  fail "у pod web нет IP — он не запущен"
else
  code=$(kubectl -n "$NS" run check-$RANDOM --rm -i --restart=Never --quiet \
    --image=busybox:1.36 --command -- \
    wget -q -S -O /dev/null -T 5 "http://$ip" 2>&1 | awk '/HTTP\//{print $2; exit}')
  if [ "$code" = "200" ]; then ok "web отвечает HTTP 200 на $ip:80"
  else fail "web не ответил 200 (получено '${code:-пусто}')" "pod web должен обслуживать nginx на порту 80"; fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
