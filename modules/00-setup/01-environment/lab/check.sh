#!/usr/bin/env bash
# Автопроверка лабы. Ничего не меняет ни в кластере, ни в kubeconfig.
# Код выхода 0 — все задания выполнены.
set -uo pipefail
NS="lab-00-01"
LAB="$(cd "$(dirname "$0")" && pwd)"
KIND_CONFIG="$LAB/../../../../env/kind-config.yaml"
FRAGMENT="$LAB/start/kubeconfig-lab.yaml"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }

# Значение поля ресурса или пустая строка
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" --request-timeout=10s 2>/dev/null; }
# Значение ключа из ConfigMap answers (без пробелов по краям)
answer() { jp configmap/answers "{.data.$1}" | tr -d '[:space:]'; }
# Поле контекста по имени из kubeconfig (без похода в кластер)
ctx_field() { kubectl config view -o jsonpath="{.contexts[?(@.name==\"$1\")].context.$2}" 2>/dev/null; }
# Номер minor-версии из JSON вида {"minor": "37", ...}
minor() { sed -n 's/.*"minor": *"\([0-9]*\).*/\1/p' | head -1; }

echo "Задание 1. Кластер готов"
if ! kubectl get --raw /version --request-timeout=10s >/dev/null 2>&1; then
  fail "kubectl не может достучаться до api-server в текущем контексте" "kubectl config view --minify; поднимите кластер: ./env/up.sh"
  echo; echo "Итог: $PASS пройдено, $FAIL не пройдено (дальше проверять нечего)"; exit 1
fi

cluster=$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}')
if [ "$cluster" = "kind-k8s-course" ]; then ok "текущий контекст $(kubectl config current-context) смотрит в кластер kind-k8s-course"
else fail "текущий контекст смотрит в кластер '$cluster', ожидался kind-k8s-course" "kubectl config get-contexts; kubectl config use-context kind-k8s-course"; fi

total=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
ready=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c '^True$')
if [ "$total" = "3" ] && [ "$ready" = "3" ]; then ok "3 узла, все Ready"
else fail "узлов $total, из них Ready: $ready (ожидалось 3 и 3)" "kubectl get nodes; кластер создан не из env/? ./env/down.sh && ./env/up.sh"; fi

server_minor=$(kubectl get --raw /version | minor)
client_minor=$(kubectl version --client -o json 2>/dev/null | minor)
server_ver=$(kubectl get --raw /version | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p')
if [ "$server_minor" != "37" ]; then
  fail "версия api-server $server_ver, ожидалась v1.37.x" "кластер должен быть создан из env/kind-config.yaml"
elif [ -z "$client_minor" ] || [ $(( client_minor > server_minor ? client_minor - server_minor : server_minor - client_minor )) -gt 1 ]; then
  fail "kubectl 1.${client_minor:-?} и api-server 1.$server_minor: разница больше одной minor-версии" "kubectl version; поставьте kubectl из env/vm-setup.sh"
else
  ok "api-server $server_ver, kubectl 1.$client_minor — в пределах version skew"
fi

if ! kubectl get ns "$NS" --request-timeout=10s >/dev/null 2>&1; then
  fail "namespace $NS не найден" "kubectl create namespace $NS"
  echo; echo "Итог: $PASS пройдено, $FAIL не пройдено (без namespace остальные задания не проверить)"; exit 1
fi
ok "namespace $NS существует"

echo "Задание 2. Свой контекст"
if [ -z "$(kubectl config get-contexts -o name 2>/dev/null | grep -x lab-00-01)" ]; then
  fail "контекста lab-00-01 нет в kubeconfig" "kubectl config set-context --help"
else
  c=$(ctx_field lab-00-01 cluster); u=$(ctx_field lab-00-01 user); n=$(ctx_field lab-00-01 namespace)
  if [ "$c" != "kind-k8s-course" ] || [ "$u" != "kind-k8s-course" ]; then
    fail "контекст lab-00-01: кластер '$c', пользователь '$u' (ожидались kind-k8s-course и kind-k8s-course)" "kubectl config get-contexts"
  elif [ "$n" != "$NS" ]; then
    fail "контекст lab-00-01: namespace '${n:-не задан}', ожидался $NS" "kubectl config set-context lab-00-01 --namespace=..."
  else
    ok "контекст lab-00-01: kind-k8s-course / kind-k8s-course / $NS"
  fi
  cur=$(kubectl config current-context 2>/dev/null)
  if [ "$cur" = "lab-00-01" ]; then ok "lab-00-01 — текущий контекст"
  else fail "текущий контекст '$cur', ожидался lab-00-01" "kubectl config use-context lab-00-01"; fi
fi

if ! kubectl -n "$NS" get pod hello --request-timeout=10s >/dev/null 2>&1; then
  where=$(kubectl get pods -A --field-selector metadata.name=hello --no-headers 2>/dev/null | awk '{print $1}' | head -1)
  if [ -n "$where" ]; then fail "pod hello создан в namespace '$where', а не в $NS" "какой namespace по умолчанию у контекста, в котором вы его создавали?"
  else fail "pod hello в $NS не найден" "kubectl run hello --image=nginx:1.27-alpine"; fi
else
  image=$(jp pod/hello '{.spec.containers[0].image}'); phase=$(jp pod/hello '{.status.phase}')
  if [ "$image" != "nginx:1.27-alpine" ]; then fail "pod hello: образ '$image', ожидался nginx:1.27-alpine" "удалите pod и создайте заново с нужным образом"
  elif [ "$phase" != "Running" ]; then fail "pod hello в фазе $phase, ожидалась Running" "kubectl -n $NS describe pod hello"
  else ok "pod hello работает в $NS"; fi
fi

echo "Задание 3. Починить"
case ":${KUBECONFIG:-}:" in
  *kubeconfig-lab.yaml*) ok "файл kubeconfig-lab.yaml подключён через KUBECONFIG" ;;
  *) fail "в KUBECONFIG нет kubeconfig-lab.yaml (сейчас: '${KUBECONFIG:-не задана}')" "export KUBECONFIG=~/.kube/config:\$PWD/start/kubeconfig-lab.yaml и запустите проверку в том же терминале" ;;
esac

# Проверяем исправленный файл поверх основного kubeconfig — независимо от того, как задан KUBECONFIG
merged="${KUBECONFIG:-$HOME/.kube/config}:$FRAGMENT"
kc() { KUBECONFIG="$merged" kubectl "$@"; }
if [ -z "$(kc config get-contexts -o name 2>/dev/null | grep -x course-lab)" ]; then
  fail "в start/kubeconfig-lab.yaml нет контекста course-lab" "git checkout -- start/kubeconfig-lab.yaml и начните заново"
elif ! err=$(kc --context course-lab config view --minify 2>&1 >/dev/null) || [ -n "$err" ]; then
  fail "контекст course-lab ссылается на то, чего нет в kubeconfig: ${err#error: }" "kubectl config get-clusters; kubectl config get-users"
else
  n=$(kc --context course-lab config view --minify -o jsonpath='{.contexts[0].context.namespace}')
  if [ "$n" != "$NS" ]; then
    fail "контекст course-lab смотрит в namespace '${n:-default}', а pod hello живёт в $NS" "kubectl get ns"
  elif [ "$(kc --context course-lab get pod hello -o name --request-timeout=10s 2>/dev/null)" = "pod/hello" ]; then
    ok "kubectl --context course-lab get pod hello находит pod"
  else
    fail "kubectl --context course-lab get pod hello не находит pod" "выполните команду сами и прочитайте ошибку; pod hello из задания 2 существует?"
  fi
fi

echo "Задание 4. Как kind связан с вашей машиной"
if ! kubectl -n "$NS" get configmap answers --request-timeout=10s >/dev/null 2>&1; then
  fail "ConfigMap answers в $NS не найден" "команда создания — в условии задания 4"
else
  server=$(kubectl config view -o jsonpath='{.clusters[?(@.name=="kind-k8s-course")].cluster.server}')
  want=${server##*:}; want=${want%%/*}; got=$(answer api-port)
  if [ "$got" = "$want" ]; then ok "api-port: $got"
  else fail "api-port: записано '$got', неверно" "docker port k8s-course-control-plane — куда проброшен 6443/tcp?"; fi

  want=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' '); got=$(answer node-containers)
  if [ "$got" = "$want" ]; then ok "node-containers: $got"
  else fail "node-containers: записано '$got', неверно" "docker ps --filter label=io.x-k8s.kind.cluster=k8s-course"; fi

  want=$(sed -n 's/^ *image: *\([^@ ]*\).*/\1/p' "$KIND_CONFIG" | head -1); got=$(answer node-image)
  if [ -n "$got" ] && [ "${got%%@*}" = "$want" ]; then ok "node-image: $got"
  else fail "node-image: записано '$got', неверно" "docker ps — колонка IMAGE (репозиторий:тег)"; fi

  want=$(awk '/containerPort: *80$/{getline; sub(/.*hostPort: */, ""); print; exit}' "$KIND_CONFIG"); got=$(answer ingress-host-port)
  if [ -n "$want" ] && [ "$got" = "$want" ]; then ok "ingress-host-port: $got"
  else fail "ingress-host-port: записано '$got', неверно" "docker port k8s-course-control-plane — куда проброшен 80/tcp?"; fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
