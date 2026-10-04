# Лабораторная: Pods: жизненный цикл

**Namespace:** `lab-02-02` · **Время:** 30–45 мин · **Проверка:** `./check.sh`

В этой лабе вы подготовите pod init-контейнером, прокинете метаданные через Downward API, почините падающий init-контейнер и добавите нативный sidecar.

## Подготовка
```bash
kubectl create namespace lab-02-02
kubectl config set-context --current --namespace=lab-02-02
```
Ответы записывайте в ConfigMap `answers`:
```bash
kubectl create configmap answers --from-literal=ключ=значение \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Задание 1. Подготовка init-контейнером
Создайте pod `web`, в котором:
- init-контейнер `content` (образ `busybox:1.36`) записывает строку `<h1>from init</h1>` в файл `index.html` в общем томе;
- контейнер `nginx` (`nginx:1.27-alpine`) отдаёт этот файл (том смонтирован в `/usr/share/nginx/html`).

Pod должен стать `Ready`, а `nginx` — отдавать по HTTP ровно то, что записал init.

<details><summary>Подсказка 1</summary>

Общий том — `emptyDir`. init пишет в `/html/index.html`, nginx монтирует тот же том в `/usr/share/nginx/html`. Проверка сама заберёт страницу из временного pod.
</details>

## Задание 2. Downward API
Создайте pod `info` (образ `busybox:1.36`, живёт долго), которому через Downward API проброшена переменная окружения `MY_NODE` со значением имени узла (`spec.nodeName`). Запишите это имя в ConfigMap `answers`:

| Ключ | Что записать |
|---|---|
| `node` | имя узла, на котором работает `info` (оно же в `MY_NODE`) |

<details><summary>Подсказка 1</summary>

`env: [{name: MY_NODE, valueFrom: {fieldRef: {fieldPath: spec.nodeName}}}]`. Прочитать: `kubectl exec info -- printenv MY_NODE`.
</details>

## Задание 3. Починить init-контейнер
Примените `start/broken.yaml` — pod `fixme` застревает, потому что его init-контейнер падает. Добейтесь, чтобы `fixme` стал `Ready`. Чинить нужно команду init-контейнера, остальное не трогайте.

```bash
kubectl apply -f start/broken.yaml
```

<details><summary>Подсказка 1</summary>

`kubectl get pod fixme` покажет `Init:CrashLoopBackOff`. Причину даст `kubectl logs fixme -c setup`.
</details>
<details><summary>Подсказка 2</summary>

В команде init-контейнера опечатка в имени утилиты. Исправьте её (манифест можно поправить и применить заново, pod пересоздайте).
</details>

## Задание 4. Нативный sidecar
Создайте pod `withcar`, где:
- основной контейнер `app` — `nginx:1.27-alpine`;
- нативный sidecar `logger` — init-контейнер `busybox:1.36` с `restartPolicy: Always`, который бесконечно что-то пишет (например, `while true; do echo tick; sleep 10; done`).

Pod должен быть `Ready`, а sidecar `logger` — работать (не завершаться).

<details><summary>Подсказка 1</summary>

sidecar объявляется в `initContainers` с `restartPolicy: Always`. Проверить, что он работает: `kubectl get pod withcar -o jsonpath='{.status.initContainerStatuses[*].state}'`.
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
