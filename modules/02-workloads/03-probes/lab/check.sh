#!/usr/bin/env bash
# Автопроверка лабы. Проверяет состояние кластера. Код выхода 0 — всё пройдено.
set -uo pipefail
NS="lab-02-03"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }
ready() { jp pod/"$1" '{.status.conditions[?(@.type=="Ready")].status}'; }
# ready-флаг эндпоинта по IP pod
ep_ready() { # $1 = podIP
  kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=web \
    -o jsonpath="{range .items[*].endpoints[*]}{.addresses[0]}={.conditions.ready}{'\n'}{end}" 2>/dev/null \
    | awk -F= -v ip="$1" '$1==ip{print $2}'
}

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с «Подготовки»"; exit 1; }

echo "Задание 1. Пробы на pod"
if ! kubectl -n "$NS" get pod web >/dev/null 2>&1; then
  fail "pod web не найден" "kubectl apply -f solution/web.yaml"
else
  rp=$(jp pod/web '{.spec.containers[0].readinessProbe.httpGet.port}')
  lp=$(jp pod/web '{.spec.containers[0].livenessProbe.httpGet.port}')
  if [ -z "$rp" ] || [ -z "$lp" ]; then fail "у web нет readiness и/или liveness httpGet-пробы" "добавьте обе пробы на / порт 80"
  elif [ "$(ready web)" != "True" ]; then fail "pod web не Ready" "kubectl -n $NS describe pod web"
  else ok "pod web: readiness+liveness настроены, Ready 1/1"; fi
fi

echo "Задание 2. Readiness и эндпоинты"
if ! kubectl -n "$NS" get svc web >/dev/null 2>&1; then
  fail "Service web не найден" "kubectl apply -f solution/notready.yaml"
elif ! kubectl -n "$NS" get pod notready >/dev/null 2>&1; then
  fail "pod notready не найден" "создайте pod notready с всегда падающей readiness"
else
  wip=$(jp pod/web '{.status.podIP}'); nip=$(jp pod/notready '{.status.podIP}')
  wr=$(ep_ready "$wip"); nr=$(ep_ready "$nip")
  if [ "$wr" = "true" ] && [ "$nr" != "true" ]; then
    ok "в эндпоинтах web: web ready=true, notready ready=${nr:-отсутствует}"
  else
    fail "эндпоинты не как ожидалось: web=${wr:-?}, notready=${nr:-?}" "у web readiness должна проходить, у notready — падать; подождите ~10с"
  fi
fi

echo "Задание 3. Починить liveness"
if ! kubectl -n "$NS" get pod api >/dev/null 2>&1; then
  fail "pod api не найден" "kubectl apply -f start/broken.yaml и почините пробу"
else
  port=$(jp pod/api '{.spec.containers[0].livenessProbe.httpGet.port}')
  cport=$(jp pod/api '{.spec.containers[0].ports[0].containerPort}')
  if [ "$(ready api)" != "True" ]; then fail "pod api не Ready" "kubectl -n $NS describe pod api — liveness бьёт не на тот порт?"
  elif [ -n "$port" ] && [ "$port" != "$cport" ]; then fail "liveness бьёт на порт $port, контейнер слушает $cport" "направьте пробу на $cport"
  else ok "pod api: liveness на правильном порту, Ready"; fi
fi

echo "Задание 4. Корректное завершение"
if ! kubectl -n "$NS" get pod graceful >/dev/null 2>&1; then
  fail "pod graceful не найден" "kubectl apply -f solution/graceful.yaml"
else
  gp=$(jp pod/graceful '{.spec.terminationGracePeriodSeconds}')
  pre=$(jp pod/graceful '{.spec.containers[0].lifecycle.preStop.exec.command}')
  if [ "$gp" != "30" ]; then fail "terminationGracePeriodSeconds=$gp, ожидалось 30"
  elif ! echo "$pre" | grep -q 'quit'; then fail "нет preStop с 'nginx -s quit' (сейчас: '$pre')"
  else ok "graceful: terminationGracePeriodSeconds=30 и preStop настроены"; fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
