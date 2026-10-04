# Решение: Архитектура Kubernetes

Все команды — из каталога `lab/`, текущий namespace `lab-01-01`.

## Задание 1. Осмотреться в кластере
```bash
kubectl cluster-info                          # api-server: https://127.0.0.1:<порт>
kubectl get pods -n kube-system -o wide       # etcd-k8s-course-control-plane → узел k8s-course-control-plane
                                              # kube-proxy-xxxxx — 3 штуки, по одному на узел
kubectl get nodes -o wide                     # CONTAINER-RUNTIME: containerd://2.3.4 → containerd
```
Порт api-server в kind выбирается случайно при создании кластера, поэтому ответ у каждого свой. То же из kubeconfig: `kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}'`.

kube-proxy работает на **каждом** узле, включая control-plane, поэтому их 3, а не 2.

Скрипт `solution/answers.sh` собирает все ответы (включая ключ из задания 2) автоматически.

## Задание 2. Увидеть reconcile loop
```bash
kubectl create deployment web --image=nginx:1.27-alpine --replicas=3
kubectl rollout status deployment/web
kubectl delete pod $(kubectl get pod -l app=web -o name | head -1 | cut -d/ -f2)
kubectl get pods -l app=web          # снова 3, у одного AGE меньше
kubectl get events --sort-by=.lastTimestamp | grep SuccessfulCreate
```
Эквивалентный манифест — `solution/web.yaml`.

Ответ `recreated-by`: **kube-controller-manager**. Точнее, ReplicaSet controller, который работает внутри него: Deployment создал ReplicaSet, а ReplicaSet controller увидел «нужно 3, есть 2» и создал pod. В событиях источник — `replicaset-controller`. Затем новый pod прошёл обычный путь: scheduler выбрал узел, kubelet запустил контейнер.

## Задание 3. Починить
Проблем две, и видны они по очереди:

1. **`schedulerName: default-schedular`** (опечатка). Симптом: `Pending`, `Node: <none>`, `Events: <none>`. Стандартный kube-scheduler обрабатывает только pod с `schedulerName: default-scheduler`, а планировщика с именем `default-schedular` в кластере нет. Pod никто не пытается планировать, поэтому нет даже события `FailedScheduling`.
   Поле `schedulerName` неизменяемое: `kubectl apply` ответит `Forbidden: pod updates may not change fields...`. Pod нужно пересоздать.
2. **`image: nginx:1.27-alpne`** (опечатка в теге). После исправления первой ошибки pod назначается на узел (`Node:` заполнен, событие `Scheduled` от `default-scheduler`), но kubelet не может скачать образ: `ErrImagePull` → `ImagePullBackOff`, в событиях `Failed to pull image "nginx:1.27-alpne": ... not found`. Scheduler свою работу сделал, споткнулся kubelet (точнее, containerd по его просьбе).

```bash
kubectl delete pod broken
kubectl apply -f solution/broken.yaml
kubectl wait --for=condition=Ready pod/broken --timeout=120s
```

## Задание 4. Мимо планировщика
```bash
kubectl apply -f solution/manual.yaml
kubectl get pod manual -o wide        # NODE: k8s-course-control-plane
kubectl describe pod manual | sed -n '/^Events/,$p'
```
Scheduler работает только с pod, у которых пуст `spec.nodeName`. Если поле заполнено сразу, kubelet указанного узла видит «этот pod — мой» и запускает его. Taint `node-role.kubernetes.io/control-plane:NoSchedule` учитывает именно scheduler, поэтому здесь он не мешает. В событиях pod нет строки `Scheduled` от `default-scheduler`: первое событие уже от kubelet.

В реальной жизни `nodeName` вручную почти не задают: pod теряет перепланирование, проверку ресурсов и правил. Для размещения pod на нужных узлах есть `nodeSelector`, affinity и tolerations (урок 06-02). Но этот трюк хорошо показывает границу ответственности: scheduler только выбирает узел.
