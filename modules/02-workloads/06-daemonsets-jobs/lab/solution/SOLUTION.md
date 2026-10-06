# Решение: DaemonSet, Job и CronJob

Все команды — из каталога `lab/`, текущий namespace `lab-02-06`.

## Задания 1–2. Агент на каждом узле
`solution/node-agent.yaml` — DaemonSet без `replicas`. Имя узла приходит в `NODE_NAME` через Downward API (`fieldRef: spec.nodeName`), поэтому одна и та же команда в каждом pod пишет своё имя.
```bash
kubectl apply -f solution/node-agent.yaml
kubectl rollout status ds/node-agent
kubectl get pods -l app=node-agent -o wide       # по одному pod на узел
kubectl logs -l app=node-agent --prefix          # k8s-course-worker ok, ...
```
Без блока `tolerations` (задание 1) `DESIRED` будет 2: на control-plane стоит taint `node-role.kubernetes.io/control-plane:NoSchedule`. Toleration к нему (задание 2) — та же, что у `kube-proxy`, — пускает агент и туда, `DESIRED` становится 3. Добавление toleration меняет шаблон pod, поэтому DaemonSet проводит rolling update по узлам.

## Задание 3. Параллельная задача
`solution/batch.yaml`: `completions: 6`, `parallelism: 2`, `completionMode: Indexed`. Номер куска pod берёт из `JOB_COMPLETION_INDEX`.
```bash
kubectl apply -f solution/batch.yaml
kubectl get pods -l job-name=batch -w            # одновременно Running не больше двух
kubectl wait --for=condition=complete job/batch --timeout=120s
kubectl logs -l job-name=batch --tail=-1 | sort  # part 0 done … part 5 done
```
`completionMode` у созданной Job менять нельзя, а `completions` у Indexed Job — только вместе с `parallelism`; проще удалить Job и создать заново.

## Задание 4. Почините проверку api
Ошибок две, и видны они по очереди:
1. `kubectl apply -f start/broken.yaml` создаёт Deployment и Service, а на CronJob отвечает:
   `The CronJob "api-check" is invalid: spec.jobTemplate.spec.template.spec.restartPolicy: Required value: valid values: "OnFailure", "Never"`. Job должен завершаться, поэтому `Always` для него недопустим.
2. После замены на `Never` CronJob создаётся, но каждая Job падает (`Failed`, `BackoffLimitExceeded`):
   ```bash
   kubectl get jobs                                 # api-check-<число>   Failed   0/1
   kubectl logs job/api-check-<число>               # wget: download timed out
   kubectl get svc api                              # PORT(S) 80/TCP — а команда ходит на :8080
   ```
   8080 — порт контейнера, а Service слушает 80 (урок 02-05). Правильный адрес — `http://api`.

Исправленный CronJob — `solution/api-check.yaml`:
```bash
kubectl apply -f solution/api-check.yaml
kubectl create job --from=cronjob/api-check api-check-debug   # проверить сразу, не дожидаясь минуты
kubectl logs job/api-check-debug                               # shop api ok
kubectl get jobs -w                                            # и дождаться планового запуска
```
Проверка засчитывает только **плановый** запуск (у него есть аннотация `batch.kubernetes.io/cronjob-scheduled-timestamp`), чтобы убедиться, что исправлен сам CronJob, а не только разовая Job.

## Задание 5. Ночной отчёт
`solution/nightly-report.yaml`:
- `schedule: "30 3 * * *"` и `timeZone: Europe/Moscow` — без `timeZone` 03:30 считалось бы по UTC (в kind это часовой пояс kube-controller-manager);
- `concurrencyPolicy: Forbid` — новый запуск пропускается, пока идёт прошлый;
- `jobTemplate.spec.activeDeadlineSeconds: 120` — дольше 2 минут Job убивается с причиной `DeadlineExceeded`;
- `successfulJobsHistoryLimit: 1`, `failedJobsHistoryLimit: 1`.
```bash
kubectl apply -f solution/nightly-report.yaml
kubectl get cronjob nightly-report                 # SCHEDULE 30 3 * * *, TIMEZONE Europe/Moscow
kubectl create job --from=cronjob/nightly-report nightly-report-manual
kubectl wait --for=condition=complete job/nightly-report-manual --timeout=60s
```
