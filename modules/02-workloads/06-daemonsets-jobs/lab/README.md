# Лабораторная: DaemonSet, Job и CronJob

**Namespace:** `lab-02-06` · **Время:** 40–60 мин · **Проверка:** `./check.sh`

В этой лабе вы развернёте агент на каждом узле кластера, распараллелите разовую задачу, почините CronJob, который проверяет api из `shop`, и спроектируете ночной отчёт по расписанию.

## Подготовка
```bash
kubectl create namespace lab-02-06
kubectl config set-context --current --namespace=lab-02-06
```

## Задание 1. Агент на каждом worker
В namespace должен работать DaemonSet `node-agent` (`busybox:1.36`, метка pod `app=node-agent`): на **каждом** worker-узле ровно один pod, и каждый pod раз в 30 секунд пишет в лог строку `<имя своего узла> ok`. Имя узла не зашивайте в команду — pod должен узнать его сам.

<details><summary>Подсказка 1</summary>

Каркас манифеста похож на Deployment, только `kind: DaemonSet` и без `replicas`. Команда: `sh -c 'while true; do echo "$NODE_NAME ok"; sleep 30; done'`.
</details>

<details><summary>Подсказка 2</summary>

Переменную `NODE_NAME` заполняет Downward API (02-02): `valueFrom.fieldRef.fieldPath: spec.nodeName`. Проверьте: `kubectl logs -l app=node-agent --prefix`.
</details>

## Задание 2. И на control-plane
Агент нужен на **всех** узлах кластера, включая control-plane: число pod `node-agent` равно числу узлов, и все готовы. Узлы и их настройки не меняйте.

<details><summary>Подсказка 1</summary>

`kubectl get ds node-agent` показывает `DESIRED 2`, а узлов три. Посмотрите, чем control-plane отличается: `kubectl describe node k8s-course-control-plane | grep Taints`.
</details>

<details><summary>Подсказка 2</summary>

Добавьте в шаблон pod `tolerations` для ключа `node-role.kubernetes.io/control-plane` с `operator: Exists` и `effect: NoSchedule`. Сравните с `kubectl -n kube-system get ds kube-proxy -o yaml`.
</details>

## Задание 3. Параллельная задача
Нужен Job `batch` (`busybox:1.36`), который выполняет работу из 6 кусков: каждый pod печатает `part <номер куска> done` (номера 0…5) и работает ~3 секунды. Одновременно работают не больше 2 pod. Job должен завершиться успешно (`6/6`).

Не задавайте `ttlSecondsAfterFinished` меньше часа — иначе Job удалится раньше, чем его увидит проверка.

<details><summary>Подсказка 1</summary>

Нужны `completions`, `parallelism` и режим, в котором pod получает номер своего куска. Каркас: `kubectl create job batch --image=busybox:1.36 --dry-run=client -o yaml -- sh -c '...'`.
</details>

<details><summary>Подсказка 2</summary>

`completionMode: Indexed` — номер куска в переменной `JOB_COMPLETION_INDEX`. `completionMode` у существующей Job поменять нельзя — удалите её и создайте заново.
</details>

## Задание 4. Почините проверку api
```bash
kubectl apply -f start/broken.yaml
```
Манифест разворачивает ярус `api` из `shop` и CronJob `api-check`, который каждую минуту должен проверять, что api отвечает. Сейчас проверка не работает. Почините CronJob так, чтобы **запуск по расписанию** завершился успешно и получил от api ответ `shop api ok`. Deployment и Service `api` не меняйте.

<details><summary>Подсказка 1</summary>

Внимательно прочитайте, что ответил `kubectl apply`: один из трёх объектов не создан.
</details>

<details><summary>Подсказка 2</summary>

Когда CronJob создастся, подождите минуту и смотрите `kubectl get jobs`, `kubectl logs job/<имя>`. Сверьте адрес в команде с `kubectl get svc api`.
</details>

<details><summary>Подсказка 3</summary>

Две ошибки: `restartPolicy: Always` недопустим для Job (нужен `Never` или `OnFailure`), а Service `api` слушает порт 80, не 8080. Проверке нужен запуск по расписанию: Job, созданная вручную через `--from`, тоже подойдёт для отладки, но дождитесь и плановой.
</details>

## Задание 5. Ночной отчёт
Спроектируйте CronJob `nightly-report` (`busybox:1.36`, печатает любую строку отчёта):
- запускается каждый день в **03:30 по Москве**, независимо от часового пояса кластера;
- никогда не работает в двух экземплярах одновременно;
- один запуск может длиться не дольше 2 минут — дольше считается сбоем;
- хранит только последнюю успешную и последнюю неудачную Job.

Не дожидаясь ночи, убедитесь, что задача работает: Job `nightly-report-manual`, созданная из этого CronJob, должна успешно завершиться.

<details><summary>Подсказка 1</summary>

Нужные поля: `schedule`, `timeZone`, `concurrencyPolicy`, `successfulJobsHistoryLimit`, `failedJobsHistoryLimit` у CronJob и `activeDeadlineSeconds` в `jobTemplate.spec`. Справка: `kubectl explain cronjob.spec`.
</details>

<details><summary>Подсказка 2</summary>

Ручной запуск: `kubectl create job --from=cronjob/nightly-report nightly-report-manual`.
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
