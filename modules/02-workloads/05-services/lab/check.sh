#!/usr/bin/env bash
# Автопроверка лабы. Ничего не меняет в кластере (кроме временных pod-проверок).
# Код выхода 0 — все задания выполнены.
set -uo pipefail
NS="lab-02-05"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }

# Значение поля ресурса или пустая строка
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }

# Выполнить команду в одноразовом pod внутри кластера и вернуть её вывод.
# Ждём завершения и читаем логи, а не attach: так нет гонки на быстрых командах.
in_cluster() {
  local name="check-$RANDOM" phase=""
  kubectl -n "$NS" run "$name" --restart=Never --image=busybox:1.36 \
    --labels=lab-check=true --command -- sh -c "$1" >/dev/null 2>&1 || return 1
  for _ in $(seq 1 30); do
    phase=$(jp "pod/$name" '{.status.phase}')
    [ "$phase" = "Succeeded" ] || [ "$phase" = "Failed" ] && break
    sleep 1
  done
  kubectl -n "$NS" logs "$name" 2>/dev/null
  kubectl -n "$NS" delete pod "$name" --wait=false >/dev/null 2>&1
}
in_cluster_get() { in_cluster "wget -qO- -T 5 $1"; }

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с раздела «Подготовка»"; exit 1; }

echo "Задание 1. ClusterIP и доступ по имени"
ready=$(jp deployment/web '{.status.readyReplicas}')
if ! kubectl -n "$NS" get deployment web >/dev/null 2>&1; then
  fail "Deployment web не найден"
elif [ "${ready:-0}" != "3" ]; then
  fail "Deployment web: готово ${ready:-0}/3 реплик" "kubectl -n $NS get pods -l app=web"
else
  ok "Deployment web: 3/3 реплик"
fi
if ! kubectl -n "$NS" get svc web >/dev/null 2>&1; then
  fail "Service web не найден"
else
  type=$(jp svc/web '{.spec.type}')
  tport=$(jp svc/web '{.spec.ports[0].targetPort}')
  if [ "$type" != "ClusterIP" ]; then fail "Service web: тип $type, ожидался ClusterIP"
  elif [[ "$tport" =~ ^[0-9]+$ ]]; then fail "Service web: targetPort=$tport задан номером, нужен по имени" "дайте порту контейнера name: http и укажите targetPort: http"
  elif in_cluster_get http://web | grep -q "Welcome to nginx"; then ok "http://web отдаёт страницу nginx (targetPort: $tport)"
  else fail "http://web не отдаёт страницу nginx" "kubectl -n $NS describe svc web — есть ли Endpoints?"; fi
fi

echo "Задание 2. NodePort наружу"
if ! kubectl -n "$NS" get svc web-np >/dev/null 2>&1; then
  fail "Service web-np не найден"
else
  type=$(jp svc/web-np '{.spec.type}'); np=$(jp svc/web-np '{.spec.ports[0].nodePort}')
  if [ "$type" != "NodePort" ]; then fail "Service web-np: тип $type, ожидался NodePort"
  elif [ "$np" != "30080" ]; then fail "Service web-np: nodePort=$np, ожидался 30080" "только 30080 проброшен на хост"
  elif curl -s -m 5 http://localhost:30080 | grep -q "Welcome to nginx"; then ok "http://localhost:30080 отдаёт страницу nginx"
  else fail "http://localhost:30080 не отвечает страницей nginx" "kubectl -n $NS describe svc web-np"; fi
fi

echo "Задание 3. Headless-Service"
if ! kubectl -n "$NS" get svc web-h >/dev/null 2>&1; then
  fail "Service web-h не найден"
else
  cip=$(jp svc/web-h '{.spec.clusterIP}')
  if [ "$cip" != "None" ]; then
    fail "Service web-h: clusterIP=$cip, должен быть None" "clusterIP меняется только пересозданием Service"
  else
    n=$(in_cluster "nslookup web-h.$NS.svc.cluster.local" | grep -c '^Address: ')
    if [ "${n:-0}" -ge 1 ] && [ "$n" = "${ready:-0}" ]; then ok "web-h: headless, адресов pod в DNS: $n"
    else fail "web-h: адресов в DNS — ${n:-0}, а готовых pod web — ${ready:-0}" "проверьте селектор: kubectl -n $NS describe svc web-h"; fi
  fi
fi

echo "Задание 4. Починить Service api"
if ! kubectl -n "$NS" get deployment api >/dev/null 2>&1; then
  fail "Deployment api не найден" "kubectl apply -f start/broken.yaml"
else
  cport=$(jp deployment/api '{.spec.template.spec.containers[0].ports[0].containerPort}')
  img=$(jp deployment/api '{.spec.template.spec.containers[0].image}')
  if [ "$cport" != "8080" ] || [ "$img" != "hashicorp/http-echo:1.0" ]; then
    fail "Deployment api изменён (образ $img, порт $cport) — чинить нужно Service" "kubectl apply -f start/broken.yaml вернёт исходный Deployment"
  elif in_cluster_get http://api | grep -q "shop api ok"; then
    ok "http://api отвечает 'shop api ok'"
  else
    eps=$(kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=api \
      -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} {end}' 2>/dev/null)
    if [ -z "$eps" ]; then fail "http://api не отвечает: у Service нет эндпоинтов" "сравните selector Service с kubectl -n $NS get pods --show-labels"
    else fail "http://api не отвечает, хотя эндпоинты есть ($eps)" "на какой порт шлёт Service и что слушает контейнер?"; fi
  fi
fi

echo "Задание 5. Свой балансировщик"
if ! kubectl -n "$NS" get svc web-lb >/dev/null 2>&1; then
  fail "Service web-lb не найден"
else
  type=$(jp svc/web-lb '{.spec.type}'); ip=$(jp svc/web-lb '{.status.loadBalancer.ingress[0].ip}')
  if [ "$type" != "LoadBalancer" ]; then fail "Service web-lb: тип $type, ожидался LoadBalancer"
  elif [ -z "$ip" ]; then fail "web-lb: EXTERNAL-IP ещё <pending>" "запущен ли cloud-provider-kind? ./env/cloud-provider-kind.sh"
  elif curl -s -m 5 "http://$ip/" | grep -q "Welcome to nginx"; then ok "http://$ip/ отдаёт страницу nginx"
  else fail "http://$ip/ не отдаёт страницу nginx" "kubectl -n $NS describe svc web-lb"; fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
