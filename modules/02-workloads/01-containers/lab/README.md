# Лабораторная: Контейнер изнутри

**Namespace:** `lab-02-01` · **Время:** 30–45 мин · **Проверка:** `./check.sh`

В этой лабе вы соберёте multi-container pod с общей сетью, убедитесь, что контейнеры делят `localhost`, почините связь, сломанную тем, что контейнеры оказались в разных pod, и урежете права контейнера.

## Подготовка
```bash
kubectl create namespace lab-02-01
kubectl config set-context --current --namespace=lab-02-01
```
Ответы записывайте в ConfigMap `answers`:
```bash
kubectl create configmap answers --from-literal=ключ=значение \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Задание 1. Два контейнера в одном pod
В namespace `lab-02-01` создайте pod `shared` из двух контейнеров:
- `server` — образ `nginx:1.27-alpine`, порт 80;
- `client` — образ `busybox:1.36`, живёт долго (например, `sleep 3600`).

Pod должен быть `Running` со статусом `2/2`.

<details><summary>Подсказка 1</summary>

Проще написать манифест (у `kubectl run` один контейнер). Дайте `client` команду `["sh","-c","sleep 3600"]`, иначе busybox завершится и попадёт в CrashLoopBackOff.
</details>

## Задание 2. Убедиться в общей сети и записать факты
Проверьте, что `client` достаёт `server` по `localhost`, и запишите в ConfigMap `answers`:

| Ключ | Что записать |
|---|---|
| `containers` | сколько контейнеров в pod `shared` (число) |
| `pod-ip` | IP pod `shared` |

<details><summary>Подсказка 1</summary>

`kubectl exec shared -c client -- wget -qO- http://localhost` — вернёт страницу nginx. IP: `kubectl get pod shared -o jsonpath='{.status.podIP}'`.
</details>

## Задание 3. Починить: один pod вместо двух
В `start/broken.yaml` два **отдельных** pod — `srv` (nginx) и `cli` (busybox), который в цикле стучится на `http://localhost` и падает/не достаёт сервер: у разных pod разные сетевые namespace, `localhost` каждого указывает на себя.

Добейтесь, чтобы в namespace появился pod `paired` из **двух контейнеров** (`server` на nginx и `client` на busybox, живущий долго), в котором `client` достаёт `server` по `localhost`. Старые `srv`/`cli` можно удалить.

<details><summary>Подсказка 1</summary>

Нельзя «соединить» два pod сетью — их нужно собрать в один pod с двумя контейнерами (как в задании 1), назвав его `paired`.
</details>
<details><summary>Подсказка 2</summary>

Проверка сама выполнит `kubectl exec paired -c client -- wget -qO- http://localhost` и ждёт страницу nginx.
</details>

## Задание 4. Урезать права
Создайте pod `dropped` с одним контейнером `web` (`nginx:1.27-alpine`), у которого в `securityContext.capabilities` отобраны **все** capabilities (`drop: ["ALL"]`). Pod должен при этом работать (`Running`).

<details><summary>Подсказка 1</summary>

`securityContext` на уровне контейнера: `capabilities: { drop: ["ALL"] }`. Под root привязка к :80 не требует capabilities, поэтому nginx продолжит работать.
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
