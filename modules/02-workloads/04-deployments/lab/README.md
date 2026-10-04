# Лабораторная: Deployments и rollout

**Namespace:** `lab-02-04` · **Время:** 30–50 мин · **Проверка:** `./check.sh`

В этой лабе вы развернёте Deployment с репликами и requests, выкатите новую версию и откатитесь, а также почините выкат, застрявший на битом образе.

## Подготовка
```bash
kubectl create namespace lab-02-04
kubectl config set-context --current --namespace=lab-02-04
```

## Задание 1. Deployment с репликами и requests
Создайте Deployment `web`:
- 3 реплики, образ `nginx:1.27-alpine`, метка pod `app=web`, порт 80;
- у контейнера заданы `resources.requests`: `cpu: 10m`, `memory: 16Mi`;
- readinessProbe по HTTP на `/` порт 80.

Должно быть 3 готовых реплики (`3/3`).

<details><summary>Подсказка 1</summary>

`spec.selector.matchLabels` должен совпадать с `spec.template.metadata.labels` (`app: web`), иначе apply отклонится. Проверка: `kubectl get deploy web`.
</details>

## Задание 2. Выкат и откат
На Deployment `web` выкатите новый образ `nginx:1.26-alpine`, дождитесь завершения выката, затем **откатитесь** обратно. В итоге:
- текущий образ контейнера снова `nginx:1.27-alpine`;
- в истории выкатов Deployment не меньше 3 ревизий (начальная + обновление + откат);
- 3 реплики готовы.

<details><summary>Подсказка 1</summary>

`kubectl set image deployment/web web=nginx:1.26-alpine` → `kubectl rollout status deployment/web` → `kubectl rollout undo deployment/web`. История: `kubectl rollout history deployment/web`.
</details>

## Задание 3. Починить застрявший выкат
Примените `start/broken.yaml` — Deployment `api` (2 реплики) не выходит в рабочее состояние: в шаблоне опечатка в теге образа, новые pod не могут скачать образ. Добейтесь, чтобы `api` работал на `nginx:1.27-alpine` со всеми `2/2` готовыми репликами.

```bash
kubectl apply -f start/broken.yaml
```

<details><summary>Подсказка 1</summary>

`kubectl get pods -l app=api` покажет `ImagePullBackOff`; `kubectl describe pod ...` — какой образ не тянется. Исправьте образ (`kubectl set image ...` или правка манифеста).
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
