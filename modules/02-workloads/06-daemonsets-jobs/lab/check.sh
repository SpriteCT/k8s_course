#!/usr/bin/env bash
# Автопроверка лабы. Только читает состояние кластера. Код выхода 0 — все задания выполнены.
set -uo pipefail
NS="lab-02-06"
PASS=0; FAIL=0

ok()   { echo "  ✔ $1"; PASS=$((PASS+1)); }
fail() { echo "  ✘ $1"; [ -n "${2:-}" ] && echo "      → $2"; FAIL=$((FAIL+1)); }

# Значение поля ресурса или пустая строка
jp() { kubectl -n "$NS" get "$1" -o jsonpath="$2" 2>/dev/null; }

kubectl get ns "$NS" >/dev/null 2>&1 || { echo "✘ Namespace $NS не найден — начните с раздела «Подготовка»"; exit 1; }

echo "Задание 1. Агент на каждом worker"
if ! kubectl -n "$NS" get ds node-agent >/dev/null 2>&1; then
  fail "DaemonSet node-agent не найден"
else
  bad=""
  for node in $(kubectl get nodes -l '!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}'); do
    pod=$(kubectl -n "$NS" get pods -l app=node-agent --field-selector "spec.nodeName=$node" \
      -o jsonpath='{range .items[?(@.status.containerStatuses[0].ready==true)]}{.metadata.name}{"\n"}{end}' 2>/dev/null | head -1)
    if [ -z "$pod" ]; then bad="$bad $node: нет готового pod;"
    elif ! kubectl -n "$NS" logs "$pod" --tail=5 2>/dev/null | grep -qx "$node ok"; then
      bad="$bad $node: в логе $pod нет строки '$node ok';"
    fi
  done
  if [ -z "$bad" ]; then ok "на каждом worker готовый pod node-agent пишет '<узел> ok'"
  else fail "node-agent:$bad" "kubectl -n $NS get pods -l app=node-agent -o wide; kubectl -n $NS logs -l app=node-agent --prefix"; fi
fi

echo "Задание 2. И на control-plane"
if ! kubectl -n "$NS" get ds node-agent >/dev/null 2>&1; then
  fail "DaemonSet node-agent не найден"
else
  nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  desired=$(jp ds/node-agent '{.status.desiredNumberScheduled}'); ready=$(jp ds/node-agent '{.status.numberReady}')
  if [ "${desired:-0}" != "$nodes" ]; then
    fail "node-agent: DESIRED=${desired:-0}, а узлов $nodes" "kubectl describe node k8s-course-control-plane | grep Taints"
  elif [ "${ready:-0}" != "$nodes" ]; then
    fail "node-agent: готово ${ready:-0}/$nodes pod" "kubectl -n $NS rollout status ds/node-agent"
  else ok "node-agent: $ready/$nodes pod, по одному на каждый узел"; fi
fi

echo "Задание 3. Параллельная задача"
if ! kubectl -n "$NS" get job batch >/dev/null 2>&1; then
  fail "Job batch не найден"
else
  comp=$(jp job/batch '{.spec.completions}'); par=$(jp job/batch '{.spec.parallelism}')
  mode=$(jp job/batch '{.spec.completionMode}'); succ=$(jp job/batch '{.status.succeeded}')
  parts=$(kubectl -n "$NS" logs -l job-name=batch --tail=-1 2>/dev/null | sed -n 's/^part \([0-9]*\) done$/\1/p' | sort -un | tr '\n' ' ')
  if [ "$comp" != "6" ] || [ "$par" != "2" ]; then fail "batch: completions=$comp, parallelism=$par — нужно 6 и 2" "эти поля не меняются — пересоздайте Job"
  elif [ "$mode" != "Indexed" ]; then fail "batch: completionMode=$mode — pod не получают номер куска" "completionMode: Indexed и JOB_COMPLETION_INDEX"
  elif [ "${succ:-0}" != "6" ]; then fail "batch: успешно ${succ:-0}/6" "kubectl -n $NS get pods -l job-name=batch; kubectl -n $NS describe job batch"
  elif [ "$parts" != "0 1 2 3 4 5 " ]; then fail "batch: в логах куски '${parts}' вместо 0…5" "каждый pod печатает 'part \$JOB_COMPLETION_INDEX done'"
  else ok "batch: 6/6 кусков, по 2 параллельно"; fi
fi

echo "Задание 4. Почините проверку api"
if ! kubectl -n "$NS" get deployment api >/dev/null 2>&1; then
  fail "Deployment api не найден" "kubectl apply -f start/broken.yaml"
elif ! kubectl -n "$NS" get cronjob api-check >/dev/null 2>&1; then
  fail "CronJob api-check не найден" "kubectl apply -f start/broken.yaml — что ответил api-server про CronJob?"
else
  # Плановые запуски помечены аннотацией времени расписания; ручные (--from) — нет.
  scheduled=$(kubectl -n "$NS" get jobs -o jsonpath='{range .items[?(@.metadata.ownerReferences[0].name=="api-check")]}{.metadata.annotations.batch\.kubernetes\.io/cronjob-scheduled-timestamp}{" "}{.metadata.name}{" "}{.status.succeeded}{"\n"}{end}' 2>/dev/null \
    | awk '$1 != "" && NF >= 2')
  good=""
  while read -r _ job succ; do
    [ "${succ:-0}" -ge 1 ] 2>/dev/null && kubectl -n "$NS" logs -l "job-name=$job" --tail=-1 2>/dev/null | grep -q "shop api ok" && good="$job"
  done <<< "$scheduled"
  if [ -n "$good" ]; then ok "плановый запуск $good успешен и получил 'shop api ok'"
  elif [ "$(jp cj/api-check '{.spec.suspend}')" = "true" ]; then fail "api-check приостановлен (suspend: true) — плановых запусков не будет" "kubectl -n $NS patch cronjob api-check -p '{\"spec\":{\"suspend\":false}}'"
  elif [ -z "$scheduled" ]; then fail "у api-check ещё не было запусков по расписанию" "расписание — раз в минуту; подождите и смотрите kubectl -n $NS get jobs"
  else fail "ни один плановый запуск api-check не получил 'shop api ok'" "kubectl -n $NS get jobs; kubectl -n $NS logs job/<имя>"; fi
fi

echo "Задание 5. Ночной отчёт"
if ! kubectl -n "$NS" get cronjob nightly-report >/dev/null 2>&1; then
  fail "CronJob nightly-report не найден"
else
  sched=$(jp cj/nightly-report '{.spec.schedule}'); tz=$(jp cj/nightly-report '{.spec.timeZone}')
  conc=$(jp cj/nightly-report '{.spec.concurrencyPolicy}')
  hs=$(jp cj/nightly-report '{.spec.successfulJobsHistoryLimit}'); hf=$(jp cj/nightly-report '{.spec.failedJobsHistoryLimit}')
  dl=$(jp cj/nightly-report '{.spec.jobTemplate.spec.activeDeadlineSeconds}')
  manual=$(jp job/nightly-report-manual '{.status.succeeded}')
  if [ "$(echo "$sched" | awk '{print $1, $2, $3, $4, $5}')" != "30 3 * * *" ]; then fail "schedule='$sched' — это не «каждый день в 03:30»"
  elif [ "$tz" != "Europe/Moscow" ]; then fail "timeZone='$tz' — расписание будет считаться не по Москве" "spec.timeZone"
  elif [ "$conc" != "Forbid" ]; then fail "concurrencyPolicy='${conc:-Allow}' — запуски могут пойти параллельно"
  elif [ "$hs" != "1" ] || [ "$hf" != "1" ]; then fail "история: успешных=$hs, неудачных=$hf — нужно 1 и 1"
  elif [ -z "$dl" ] || [ "$dl" -gt 120 ]; then fail "activeDeadlineSeconds='${dl}' — запуск должен обрываться через 2 минуты" "поле в jobTemplate.spec"
  elif [ "${manual:-0}" -lt 1 ]; then fail "Job nightly-report-manual не найдена или не завершилась успешно" "kubectl -n $NS create job --from=cronjob/nightly-report nightly-report-manual"
  else ok "nightly-report: 03:30 по Москве, Forbid, история 1/1, таймаут ${dl}s; ручной запуск успешен"; fi
fi

echo
echo "Итог: $PASS пройдено, $FAIL не пройдено"
[ "$FAIL" -eq 0 ]
