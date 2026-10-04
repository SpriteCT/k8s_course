#!/usr/bin/env bash
# Автопроверка лабы. Проверяет состояние кластера. Код выхода 0 — всё пройдено.
set -uo pipefail
NS="lab-02-04"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с «Подготовки»"; exit 1; }

echo "Задание 1. Deployment с репликами и requests"
if ! kubectl -n "$NS" get deployment web >/dev/null 2>&1; then
  fail "Deployment web не найден" "kubectl apply -f solution/web.yaml"
else
  ready=$(jp deployment/web '{.status.readyReplicas}')
  spec=$(jp deployment/web '{.spec.replicas}')
  cpu=$(jp deployment/web '{.spec.template.spec.containers[0].resources.requests.cpu}')
  mem=$(jp deployment/web '{.spec.template.spec.containers[0].resources.requests.memory}')
  if [ "$spec" != "3" ]; then fail "web: replicas=$spec, ожидалось 3"
  elif [ "${ready:-0}" != "3" ]; then fail "web: готово ${ready:-0}/3 реплик" "kubectl -n $NS get pods -l app=web"
  elif [ -z "$cpu" ] || [ -z "$mem" ]; then fail "у контейнера web нет requests (cpu='$cpu', memory='$mem')" "добавьте resources.requests"
  else ok "web: 3/3 реплик, requests cpu=$cpu memory=$mem"; fi
fi

echo "Задание 2. Выкат и откат"
if ! kubectl -n "$NS" get deployment web >/dev/null 2>&1; then
  fail "Deployment web не найден"
else
  img=$(jp deployment/web '{.spec.template.spec.containers[0].image}')
  # число ревизий = число записей ControllerRevision/ReplicaSet с revision-аннотацией
  revs=$(kubectl -n "$NS" get rs -l app=web \
    -o jsonpath='{range .items[*]}{.metadata.annotations.deployment\.kubernetes\.io/revision}{"\n"}{end}' 2>/dev/null | grep -c .)
  if [ "$img" != "nginx:1.27-alpine" ]; then
    fail "текущий образ web — '$img', ожидался nginx:1.27-alpine (после отката)" "выкатите 1.26-alpine и откатитесь обратно"
  elif [ "${revs:-0}" -lt 2 ]; then
    fail "в истории web меньше 2 ревизий (найдено ${revs:-0})" "сделайте выкат нового образа, затем rollout undo"
  else
    ok "web: откат выполнен (образ nginx:1.27-alpine, ревизий: $revs)"
  fi
fi

echo "Задание 3. Починить застрявший выкат"
if ! kubectl -n "$NS" get deployment api >/dev/null 2>&1; then
  fail "Deployment api не найден" "kubectl apply -f start/broken.yaml и почините образ"
else
  img=$(jp deployment/api '{.spec.template.spec.containers[0].image}')
  ready=$(jp deployment/api '{.status.readyReplicas}')
  if [ "$img" != "nginx:1.27-alpine" ]; then fail "api: образ '$img', ожидался nginx:1.27-alpine" "kubectl set image deployment/api api=nginx:1.27-alpine"
  elif [ "${ready:-0}" != "2" ]; then fail "api: готово ${ready:-0}/2 реплик" "kubectl -n $NS get pods -l app=api"
  else ok "api: 2/2 реплик на nginx:1.27-alpine"; fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
