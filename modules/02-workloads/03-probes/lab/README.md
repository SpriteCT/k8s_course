# Лабораторная: Probes и graceful shutdown

**Namespace:** `lab-02-03` · **Время:** 30–45 мин · **Проверка:** `./check.sh`

В этой лабе вы настроите пробы, увидите, как неготовый pod выпадает из эндпоинтов Service, почините liveness, которая убивает живой контейнер, и настроите корректное завершение.

## Подготовка
```bash
kubectl create namespace lab-02-03
kubectl config set-context --current --namespace=lab-02-03
```

## Задание 1. Пробы на pod
Создайте pod `web` (образ `nginx:1.27-alpine`, метка `app=web`, порт 80) с двумя пробами по HTTP на `/` порт 80:
- `readinessProbe`;
- `livenessProbe`.

Pod должен стать `Ready` (`1/1`).

<details><summary>Подсказка 1</summary>

`readinessProbe` и `livenessProbe` с `httpGet: {path: /, port: 80}`. Готовность: `kubectl get pod web`.
</details>

## Задание 2. Readiness и эндпоинты
Создайте Service `web` (ClusterIP, селектор `app=web`, порт 80) — Service подробно в уроке 02-05, здесь он нужен, чтобы увидеть эндпоинты. Затем создайте pod `notready` (тот же образ, метка `app=web`), у которого `readinessProbe` **всегда проваливается** (например, HTTP на несуществующий порт 8081).

Нужно добиться, чтобы в эндпоинтах Service `web` готовый pod `web` был помечен `ready=true`, а `notready` — `ready=false` (трафик на него не идёт).

<details><summary>Подсказка 1</summary>

`kubectl get endpointslices -l kubernetes.io/service-name=web -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} {.conditions.ready}{"\n"}{end}'`. У `notready` readiness должна падать — направьте её на закрытый порт.
</details>

## Задание 3. Починить liveness
Примените `start/broken.yaml` — pod `api` периодически перезапускается: его `livenessProbe` бьёт не туда и убивает живой контейнер. Добейтесь, чтобы `api` стал `Ready` и перестал накручивать перезапуски. Чинить нужно только пробу.

```bash
kubectl apply -f start/broken.yaml
```

<details><summary>Подсказка 1</summary>

`kubectl describe pod api` → события `Liveness probe failed`. Сверьте порт/путь пробы с портом, который слушает контейнер (80).
</details>

## Задание 4. Корректное завершение
Создайте pod `graceful` (образ `nginx:1.27-alpine`), у которого задано:
- `terminationGracePeriodSeconds: 30`;
- `preStop`-хук, выполняющий `nginx -s quit`.

<details><summary>Подсказка 1</summary>

`spec.terminationGracePeriodSeconds` — на уровне pod; `lifecycle.preStop.exec.command` — на уровне контейнера.
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
