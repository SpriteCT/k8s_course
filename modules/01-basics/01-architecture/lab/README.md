# Лабораторная: Архитектура Kubernetes

**Namespace:** `lab-01-01` · **Время:** 30–45 мин · **Проверка:** `./check.sh`

В этой лабе вы найдёте компоненты кластера, увидите reconcile loop в действии, найдёте, какой компонент «сломал» запуск pod, и запустите pod в обход планировщика.

## Подготовка
```bash
kubectl create namespace lab-01-01
kubectl config set-context --current --namespace=lab-01-01
```
Вторая команда делает `lab-01-01` namespace по умолчанию, чтобы не писать `-n lab-01-01` в каждой команде.

Ответы на вопросы вы будете записывать в ConfigMap `answers`: это объект «ключ → значение» (подробно в уроке 03-01). Создать или обновить его можно так:
```bash
kubectl create configmap answers \
  --from-literal=ключ1=значение1 \
  --from-literal=ключ2=значение2 \
  --dry-run=client -o yaml | kubectl apply -f -
```
Указывайте **все** ключи каждый раз: команда заменяет ConfigMap целиком.

## Задание 1. Осмотреться в кластере
Найдите в работающем кластере ответы и запишите их в ConfigMap `answers` в namespace `lab-01-01`:

| Ключ | Что записать |
|---|---|
| `api-server` | URL kube-apiserver, к которому обращается ваш `kubectl` (вида `https://127.0.0.1:NNNNN`) |
| `etcd-node` | Имя узла, на котором работает etcd |
| `kube-proxy-pods` | Сколько pod kube-proxy работает в кластере (число) |
| `container-runtime` | Название container runtime на узлах (без версии) |

<details><summary>Подсказка 1</summary>

Все компоненты кластера живут в namespace `kube-system`. Адрес api-server показывает одна из команд шпаргалки урока.
</details>
<details><summary>Подсказка 2</summary>

`kubectl cluster-info`, `kubectl get pods -n kube-system -o wide` (колонка `NODE`), `kubectl get nodes -o wide` (колонка `CONTAINER-RUNTIME`).
</details>

## Задание 2. Увидеть reconcile loop
В namespace `lab-01-01` должен работать Deployment `web` из 3 готовых реплик образа `nginx:1.27-alpine`. Deployment — объект, который «держит N копий pod» (урок 02-03); создайте его одной командой `kubectl create deployment` (посмотрите `kubectl create deployment --help`).

Когда реплики поднимутся, удалите **любой** из его pod и понаблюдайте, что произойдёт. Затем добавьте в `answers` ключ:

| Ключ | Что записать |
|---|---|
| `recreated-by` | Имя компонента control plane, который создал pod взамен удалённого |

Проверка убедится, что Deployment работает, и что среди его pod есть «новичок», появившийся позже остальных.

<details><summary>Подсказка 1</summary>

`kubectl create deployment web --image=... --replicas=...`. Следить за pod в реальном времени: `kubectl get pods -w` (выход — Ctrl+C).
</details>
<details><summary>Подсказка 2</summary>

Кто создал pod, видно в событиях: `kubectl get events -o wide --sort-by=.lastTimestamp`, колонка `SOURCE` у события `SuccessfulCreate`. Контроллер ReplicaSet работает внутри одного из процессов control plane — какого?
</details>

## Задание 3. Починить
В `start/broken.yaml` описан pod `broken`, который должен работать на образе `nginx:1.27-alpine`. Примените его и добейтесь, чтобы pod был в состоянии `Running`:
```bash
kubectl apply -f start/broken.yaml
```
Для каждой найденной проблемы ответьте себе: **какой компонент не смог сделать свою работу и почему**. Проблем больше одной.

<details><summary>Подсказка 1</summary>

`kubectl describe pod broken`: посмотрите на строку `Node:` и раздел `Events`. Какой шаг пути pod уже состоялся, а какой — нет?
</details>
<details><summary>Подсказка 2</summary>

Нет ни одного события — значит, pod никто даже не попытался запланировать. Какое поле в `spec` говорит, **кто** должен его планировать?
</details>
<details><summary>Подсказка 3</summary>

Не все поля pod можно поменять «на лету». Если `kubectl apply` отвечает `Forbidden: pod updates may not change fields...`, удалите pod (`kubectl delete pod broken`) и примените исправленный файл заново.
</details>

## Задание 4. Мимо планировщика
Узел `k8s-course-control-plane` помечен так, что планировщик не ставит на него обычные pod (taint, урок 06-02). Запустите в `lab-01-01` pod `manual` на образе `nginx:1.27-alpine` так, чтобы он работал (`Running`) **именно на узле `k8s-course-control-plane`**. Ограничения:
- не меняйте узлы и их taints;
- не добавляйте в pod tolerations — решение должно обойтись без планировщика вообще.

<details><summary>Подсказка 1</summary>

Вспомните, что именно scheduler меняет в pod и что он делает с pod, у которых это уже заполнено.
</details>
<details><summary>Подсказка 2</summary>

Возьмите за основу `start/broken.yaml` (после исправления), поменяйте имя и добавьте одно поле в `spec`. Посмотреть описание поля: `kubectl explain pod.spec.nodeName`.
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
