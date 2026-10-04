# Лабораторная: Namespaces, labels, annotations

**Namespace:** `lab-01-03` · **Время:** 30–45 мин · **Проверка:** `./check.sh`

В этой лабе вы разложите pod по меткам, научитесь выбирать их группами, почините разорванную селектором связь и навесите аннотацию.

## Подготовка
```bash
kubectl create namespace lab-01-03
kubectl config set-context --current --namespace=lab-01-03
```
Ответы записывайте в ConfigMap `answers` (объект «ключ → значение», подробно в уроке 03-01):
```bash
kubectl create configmap answers --from-literal=ключ=значение \
  --dry-run=client -o yaml | kubectl apply -f -
```
Указывайте **все** ключи каждый раз.

## Задание 1. Разложить по меткам
В namespace `lab-01-03` создайте четыре работающих pod на образе `nginx:1.27-alpine` со следующими метками:

| Pod | Метки |
|---|---|
| `web-1` | `app=shop`, `tier=frontend`, `env=prod` |
| `web-2` | `app=shop`, `tier=frontend`, `env=dev` |
| `api-1` | `app=shop`, `tier=api`, `env=prod` |
| `cache-1` | `app=shop`, `tier=cache` |

<details><summary>Подсказка 1</summary>

`kubectl run web-1 --image=nginx:1.27-alpine -l app=shop,tier=frontend,env=prod`. Проверить: `kubectl get pods --show-labels`.
</details>

## Задание 2. Выбрать группами
Пользуясь селекторами по меткам, посчитайте среди pod приложения (`app=shop`) и запишите в ConfigMap `answers`:

| Ключ | Что записать |
|---|---|
| `frontend-count` | сколько pod `app=shop` с `tier=frontend` |
| `prod-count` | сколько pod `app=shop` с `env=prod` |
| `no-env-count` | у скольких pod `app=shop` **нет** ключа `env` |

<details><summary>Подсказка 1</summary>

`kubectl get pods -l app=shop,tier=frontend --no-headers | wc -l`; для «нет ключа» — селектор `'app=shop,!env'`. Ограничение `app=shop` отсекает pod `front-x` из задания 3.
</details>

## Задание 3. Починить связь по селектору
В `start/broken.yaml` описаны Service `shop-front` и pod `front-x`, который должен попадать под его `selector`, но не попадает: у Service нет эндпоинтов. Примените манифест и добейтесь, чтобы у Service `shop-front` появился **хотя бы один** эндпоинт (pod стал его бэкендом).

Чинить можно только метки/селектор. Образ и порты не трогайте.

```bash
kubectl apply -f start/broken.yaml
```

<details><summary>Подсказка 1</summary>

Сравните `kubectl get svc shop-front -o jsonpath='{.spec.selector}'` и `kubectl get pod front-x --show-labels`. Эндпоинты: `kubectl get endpoints shop-front`.
</details>
<details><summary>Подсказка 2</summary>

Приведите метки pod к селектору Service (или наоборот) командой `kubectl label` или правкой манифеста. Главное — чтобы совпали все пары селектора.
</details>

## Задание 4. Аннотация
Навесьте на pod `api-1` аннотацию `owner` со значением `team-shop`. Напоминание: аннотация — для хранения, не для выбора.

<details><summary>Подсказка 1</summary>

`kubectl annotate pod api-1 owner=team-shop`. Проверить: `kubectl get pod api-1 -o jsonpath='{.metadata.annotations.owner}'`.
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
