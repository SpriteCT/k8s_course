# Решение: API и kubectl

Все команды — из каталога `lab/`, текущий namespace `lab-01-02`.

## Задание 1. Создать объект декларативно
```bash
kubectl run web --image=nginx:1.27-alpine --port=80 --labels=app=web \
  --dry-run=client -o yaml > pod.yaml
kubectl apply -f pod.yaml --dry-run=server     # проверка на сервере
kubectl apply -f pod.yaml
kubectl wait --for=condition=Ready pod/web --timeout=120s
```
`--dry-run=client` печатает заготовку, не отправляя её на сервер; `apply` создаёт объект; повторный `apply` того же файла идемпотентен. Эталон заготовки — `solution/pod.yaml`.

## Задание 2. Достать данные из кластера
```bash
kubectl get pod web -o jsonpath='{.apiVersion}'              # v1
kubectl get pod web -o jsonpath='{.spec.nodeName}'           # узел
kubectl get pod web -o jsonpath='{.spec.containers[0].image}'# nginx:1.27-alpine
kubectl get pod web -v=6 2>&1 | grep -o '/api/v1/.*/pods/web'
```
Pod — core-объект, поэтому `apiVersion: v1`, а REST-путь — `/api/v1/namespaces/lab-01-02/pods/web` (именованные группы были бы под `/apis/<группа>/...`). Скрипт `solution/answers.sh` собирает и записывает все ответы.

## Задание 3. Починить манифест
В `start/broken.yaml` три ошибки, и сервер сообщает о них по мере исправления:
1. **`apiVersion: apps/v1`** для Pod. Pod — в core-группе, у него `apiVersion: v1`. Симптом: `no matches for kind "Pod" in version "apps/v1"`.
2. **`container:`** вместо `containers:`. Симптом после починки версии: `unknown field "spec.container"`. Точное имя — `kubectl explain pod.spec`.
3. **`containerPort: "80"`** — строка вместо числа. Симптом: `cannot unmarshal string into ... int32`. Убрать кавычки.

```bash
kubectl apply -f solution/fixed.yaml
kubectl wait --for=condition=Ready pod/fixed --timeout=120s
```

## Задание 4. Доступ без Service
```bash
kubectl port-forward pod/web 8080:80 &
curl -I http://localhost:8080        # HTTP/1.1 200 OK
kill %1
```
Либо запрос из временного pod по IP:
```bash
ip=$(kubectl get pod web -o jsonpath='{.status.podIP}')
kubectl run probe --rm -it --restart=Never --image=busybox:1.36 -- wget -qO- "http://$ip"
```
Оба пути идут через api-server (он проксирует к kubelet) и не требуют прямого доступа к сети pod.
