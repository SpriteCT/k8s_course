# Лабораторная: Services

**Namespace:** `lab-02-05` · **Время:** 40–60 мин · **Проверка:** `./check.sh`

В этой лабе вы дадите Deployment стабильное имя через ClusterIP, откроете его наружу через NodePort и LoadBalancer, сделаете headless-Service и почините Service `api` из `shop`, до которого не доходит трафик.

## Подготовка
```bash
kubectl create namespace lab-02-05
kubectl config set-context --current --namespace=lab-02-05
# pod-клиент для проверок изнутри кластера
kubectl run client --image=busybox:1.36 -- sleep 3600
# для задания 5 — локальный балансировщик (из корня репозитория, повторный запуск безопасен)
../../../../env/cloud-provider-kind.sh
```
Если вы выполняли команды из урока — убедитесь, что от них ничего не осталось: `kubectl get svc -A | grep 30080` должен быть пуст.

## Задание 1. ClusterIP и доступ по имени
В namespace должен работать Deployment `web`: 3 готовые реплики `nginx:1.27-alpine`, метка pod `app=web`, порт контейнера 80 с именем `http`.

Перед ним — Service `web` типа ClusterIP: запрос к `http://web:80` из любого pod namespace возвращает страницу nginx. `targetPort` задан **по имени**, а не номером.

<details><summary>Подсказка 1</summary>

Удобно начать с `kubectl create deployment ... --dry-run=client -o yaml > web.yaml` и дописать имя порта. Service — отдельным документом в том же файле.
</details>

<details><summary>Подсказка 2</summary>

Имя задаётся у контейнера: `ports: [{containerPort: 80, name: http}]`, а в Service — `targetPort: http`. Проверьте: `kubectl exec client -- wget -qO- http://web`.
</details>

## Задание 2. NodePort наружу
Те же pod должны отвечать с вашей машины на `http://localhost:30080`. Service `web` не меняйте — сделайте отдельный Service `web-np`.

<details><summary>Подсказка 1</summary>

Порт 30080 узла control-plane проброшен на хост в `env/kind-config.yaml`. Значит, нужен Service типа NodePort с конкретным `nodePort`.
</details>

<details><summary>Подсказка 2</summary>

`type: NodePort`, в `ports`: `port: 80`, `targetPort: http`, `nodePort: 30080`. Ошибка `provided port is already allocated` значит, что 30080 занят Service из другого namespace.
</details>

## Задание 3. Headless-Service
Нужен Service `web-h`, через который клиент получает **адреса самих pod** `web`, а не один виртуальный IP: `nslookup web-h` возвращает столько адресов, сколько готовых реплик.

<details><summary>Подсказка 1</summary>

Такой Service называется headless: `clusterIP: None`. Это поле нельзя поменять у существующего Service — только создать заново.
</details>

<details><summary>Подсказка 2</summary>

`kubectl expose deployment web --name=web-h --cluster-ip=None --port=80`. Сравните `kubectl exec client -- nslookup web-h.lab-02-05.svc.cluster.local` с тем же для `web`.
</details>

## Задание 4. Почините Service api
```bash
kubectl apply -f start/broken.yaml
```
Это ярус `api` из `shop`: Deployment на `hashicorp/http-echo:1.0` и Service `api`. Pod запущены и готовы, но `http://api` из pod-клиента не отвечает. Почините так, чтобы `http://api:80` возвращал `shop api ok`. Deployment не трогайте — чинится только Service.

<details><summary>Подсказка 1</summary>

Начните с вопроса «есть ли у Service эндпоинты?»: `kubectl get endpointslices -l kubernetes.io/service-name=api` и `kubectl describe svc api`.
</details>

<details><summary>Подсказка 2</summary>

Сравните `spec.selector` Service с `kubectl get pods --show-labels`. После этой правки ошибка сменится — посмотрите, на какой порт Service шлёт и что слушает контейнер.
</details>

<details><summary>Подсказка 3</summary>

Неисправностей две: селектор не совпадает с метками pod, а `targetPort: 80` указывает мимо — http-echo слушает 8080 (порт с именем `http`).
</details>

## Задание 5. Свой балансировщик
Спроектируйте сами: pod `web` должны быть доступны с вашей машины по **отдельному внешнему IP** на порту 80 (`curl http://<IP>/`), как это было бы с облачным балансировщиком. Имя Service — `web-lb`. Существующие Service не меняйте.

<details><summary>Подсказка 1</summary>

Нужен `type: LoadBalancer`. Если `EXTERNAL-IP` долго в `<pending>` — проверьте, что запущен `cloud-provider-kind` (`docker ps --filter name=cloud-provider-kind`).
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
`cleanup.sh` удаляет namespace; контейнеры-балансировщики cloud-provider-kind исчезают вместе с Service. Сам cloud-provider-kind можно оставить работать или остановить: `./env/cloud-provider-kind.sh stop`.
