#!/usr/bin/env bash
# Автопроверка лабы. Ничего не меняет в кластере.
# Код выхода 0 — все задания выполнены.
set -uo pipefail
NS="lab-01-01"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }

# Значение поля ресурса или пустая строка
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }
# Значение ключа из ConfigMap answers (без пробелов по краям)
answer() { jp configmap/answers "{.data.$1}" | tr -d '[:space:]'; }

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с раздела «Подготовка»"; exit 1; }

CP_NODE=$(kubectl get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{.items[0].metadata.name}')

echo "Задание 1. Осмотреться в кластере"
if ! kubectl -n "$NS" get configmap answers >/dev/null 2>&1; then
  fail "ConfigMap answers не найден" "создайте его командой из раздела «Подготовка»"
else
  want=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'); got=$(answer api-server)
  if [ -n "$got" ] && [ "${got%/}" = "${want%/}" ]; then ok "api-server: $got"
  else fail "api-server: записано '${got}', не совпадает с адресом, куда ходит kubectl" "kubectl cluster-info"; fi

  want=$(kubectl -n kube-system get pods -l component=etcd -o jsonpath='{.items[0].spec.nodeName}'); got=$(answer etcd-node)
  if [ "$got" = "$want" ]; then ok "etcd-node: $got"
  else fail "etcd-node: записано '${got}', неверно" "kubectl get pods -n kube-system -o wide — колонка NODE у pod etcd-…"; fi

  want=$(kubectl -n kube-system get pods -l k8s-app=kube-proxy --no-headers 2>/dev/null | wc -l | tr -d ' '); got=$(answer kube-proxy-pods)
  if [ "$got" = "$want" ]; then ok "kube-proxy-pods: $got"
  else fail "kube-proxy-pods: записано '${got}', неверно" "посчитайте pod kube-proxy-… во всём кластере, а не только на worker-узлах"; fi

  full=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}'); got=$(answer container-runtime)
  if [ -n "$got" ] && { [ "$got" = "${full%%://*}" ] || [ "$got" = "$full" ]; }; then ok "container-runtime: $got"
  else fail "container-runtime: записано '${got}', неверно" "kubectl get nodes -o wide — колонка CONTAINER-RUNTIME (название до '://')"; fi
fi

echo "Задание 2. Увидеть reconcile loop"
if ! kubectl -n "$NS" get deployment web >/dev/null 2>&1; then
  fail "Deployment web не найден" "kubectl create deployment --help"
else
  image=$(jp deployment/web '{.spec.template.spec.containers[0].image}')
  ready=$(jp deployment/web '{.status.readyReplicas}')
  if [ "$image" != "nginx:1.27-alpine" ]; then
    fail "Deployment web: образ '$image', ожидался nginx:1.27-alpine"
  elif [ "${ready:-0}" != "3" ]; then
    fail "Deployment web: готово ${ready:-0} реплик из 3" "kubectl describe deployment web; kubectl get pods"
  else
    ok "Deployment web: 3 готовые реплики nginx:1.27-alpine"
  fi

  # Pod, созданный заметно позже Deployment, — след удаления и пересоздания
  selector=$(kubectl -n "$NS" get deployment web \
    -o go-template='{{range $k, $v := .spec.selector.matchLabels}}{{$k}}={{$v}},{{end}}' 2>/dev/null)
  selector=${selector%,}
  created=$(date -d "$(jp deployment/web '{.metadata.creationTimestamp}')" +%s)
  newest=0
  for ts in $(kubectl -n "$NS" get pods -l "$selector" -o jsonpath='{range .items[*]}{.metadata.creationTimestamp}{"\n"}{end}' 2>/dev/null); do
    t=$(date -d "$ts" +%s); [ "$t" -gt "$newest" ] && newest=$t
  done
  if [ "$newest" -ge $((created + 5)) ]; then ok "среди pod web есть пересозданный"
  else fail "все pod web созданы вместе с Deployment" "удалите один pod web и посмотрите, что произойдёт"; fi

  got=$(answer recreated-by)
  if echo "$got" | grep -Eiq '^(kube-?)?controller-?manager$|replicaset'; then ok "recreated-by: $got"
  else fail "recreated-by: записано '${got}', неверно" "kubectl get events -o wide — колонка SOURCE у события SuccessfulCreate; в каком процессе работает этот контроллер?"; fi
fi

echo "Задание 3. Починить"
if ! kubectl -n "$NS" get pod broken >/dev/null 2>&1; then
  fail "Pod broken не найден" "kubectl apply -f start/broken.yaml"
else
  sched=$(jp pod/broken '{.spec.schedulerName}')
  node=$(jp pod/broken '{.spec.nodeName}')
  image=$(jp pod/broken '{.spec.containers[0].image}')
  waiting=$(jp pod/broken '{.status.containerStatuses[0].state.waiting.reason}')
  ready=$(jp pod/broken '{.status.conditions[?(@.type=="Ready")].status}')
  if [ "$sched" != "default-scheduler" ]; then
    fail "pod broken не назначен на узел: его некому планировать" "kubectl get pod broken -o jsonpath='{.spec.schedulerName}' — существует ли такой планировщик?"
  elif [ -z "$node" ]; then
    fail "pod broken ещё не назначен на узел" "kubectl describe pod broken — раздел Events"
  elif [ "$image" != "nginx:1.27-alpine" ]; then
    fail "pod broken: образ '$image'${waiting:+ ($waiting)}, ожидался nginx:1.27-alpine" "kubectl describe pod broken — события от kubelet"
  elif [ "$ready" != "True" ]; then
    fail "pod broken назначен на $node, но не готов${waiting:+ ($waiting)}" "kubectl describe pod broken"
  else
    ok "pod broken работает на $node"
  fi
fi

echo "Задание 4. Мимо планировщика"
if ! kubectl -n "$NS" get pod manual >/dev/null 2>&1; then
  fail "Pod manual не найден"
else
  node=$(jp pod/manual '{.spec.nodeName}')
  image=$(jp pod/manual '{.spec.containers[0].image}')
  phase=$(jp pod/manual '{.status.phase}')
  # Без toleration на taint control-plane scheduler не поставил бы pod на этот узел
  tol=$(jp pod/manual '{range .spec.tolerations[*]}{.key}|{.operator}{"\n"}{end}' \
    | grep -E '^node-role\.kubernetes\.io/control-plane\||^\|Exists$')
  if [ -n "$tol" ]; then
    fail "pod manual использует tolerations — по условию нужно обойтись без планировщика" "уберите tolerations; какое поле scheduler заполняет сам?"
  elif [ "$node" != "$CP_NODE" ]; then
    fail "pod manual на узле '${node:-не назначен}', ожидался $CP_NODE" "kubectl explain pod.spec.nodeName"
  elif [ "$image" != "nginx:1.27-alpine" ]; then
    fail "pod manual: образ '$image', ожидался nginx:1.27-alpine"
  elif [ "$phase" != "Running" ]; then
    fail "pod manual на $CP_NODE, но в фазе $phase" "kubectl describe pod manual"
  else
    ok "pod manual работает на $CP_NODE без участия scheduler"
  fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
