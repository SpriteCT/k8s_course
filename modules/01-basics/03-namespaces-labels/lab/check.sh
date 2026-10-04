#!/usr/bin/env bash
# Автопроверка лабы. Проверяет состояние кластера. Код выхода 0 — всё пройдено.
set -uo pipefail
NS="lab-01-03"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }
answer() { jp configmap/answers "{.data.$1}" | tr -d '[:space:]'; }
# число pod по селектору
count() { kubectl -n "$NS" get pods -l "$1" --no-headers 2>/dev/null | grep -c .; }

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с «Подготовки»"; exit 1; }

echo "Задание 1. Разложить по меткам"
decl=0
check_pod() { # имя app tier env(может быть пусто) — Running + точные метки
  local name="$1" wapp="$2" wtier="$3" wenv="${4:-}"
  if ! kubectl -n "$NS" get pod "$name" >/dev/null 2>&1; then fail "pod $name не найден"; return; fi
  local ready app tier env
  ready=$(jp pod/"$name" '{.status.conditions[?(@.type=="Ready")].status}')
  app=$(jp pod/"$name" '{.metadata.labels.app}')
  tier=$(jp pod/"$name" '{.metadata.labels.tier}')
  env=$(jp pod/"$name" '{.metadata.labels.env}')
  if [ "$ready" != "True" ]; then fail "pod $name не готов" "kubectl -n $NS describe pod $name"
  elif [ "$app" != "$wapp" ] || [ "$tier" != "$wtier" ] || [ "$env" != "$wenv" ]; then
    fail "pod $name: метки app=$app,tier=$tier,env=$env, ожидались app=$wapp,tier=$wtier,env=$wenv"
  else decl=$((decl+1)); fi
}
check_pod web-1  shop frontend prod
check_pod web-2  shop frontend dev
check_pod api-1  shop api prod
check_pod cache-1 shop cache
[ "$decl" = "4" ] && ok "4 pod с правильными метками работают"

echo "Задание 2. Выбрать группами"
if ! kubectl -n "$NS" get configmap answers >/dev/null 2>&1; then
  fail "ConfigMap answers не найден"
else
  for pair in "frontend-count:app=shop,tier=frontend" "prod-count:app=shop,env=prod" "no-env-count:app=shop,!env"; do
    key=${pair%%:*}; sel=${pair#*:}
    want=$(count "$sel"); got=$(answer "$key")
    [ "$got" = "$want" ] && ok "$key: $got" || fail "$key: записано '$got', в кластере $want" "kubectl get pods -l '$sel' --no-headers | wc -l"
  done
fi

echo "Задание 3. Починить связь по селектору"
if ! kubectl -n "$NS" get svc shop-front >/dev/null 2>&1; then
  fail "Service shop-front не найден" "kubectl apply -f start/broken.yaml"
else
  eps=$(kubectl -n "$NS" get endpoints shop-front -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
  if [ -n "$eps" ]; then ok "у Service shop-front есть эндпоинт(ы): $eps"
  else fail "у Service shop-front нет эндпоинтов" "сравните selector Service и метки pod front-x (--show-labels)"; fi
fi

echo "Задание 4. Аннотация"
got=$(jp pod/api-1 '{.metadata.annotations.owner}')
[ "$got" = "team-shop" ] && ok "api-1: annotation owner=team-shop" || fail "api-1: annotation owner='$got', ожидалось team-shop" "kubectl annotate pod api-1 owner=team-shop"

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
