# Решение: Pods: жизненный цикл

Все команды — из каталога `lab/`, текущий namespace `lab-02-02`.

## Задание 1. Подготовка init-контейнером
```bash
kubectl apply -f solution/web.yaml
kubectl wait --for=condition=Ready pod/web --timeout=120s
ip=$(kubectl get pod web -o jsonpath='{.status.podIP}')
kubectl run probe --rm -it --restart=Never --image=busybox:1.36 -- wget -qO- "http://$ip"
# <h1>from init</h1>
```
init-контейнер `content` выполняется до `nginx` и пишет `index.html` в общий `emptyDir`; nginx монтирует тот же том и отдаёт файл.

## Задание 2. Downward API
```bash
kubectl apply -f solution/info.yaml
kubectl exec info -- printenv MY_NODE        # имя узла
kubectl get pod info -o jsonpath='{.spec.nodeName}'
```
`MY_NODE` берётся из `spec.nodeName` через `fieldRef`, без обращения к API-серверу. Ответ `node` записывает `solution/answers.sh`.

## Задание 3. Починить init-контейнер
Причина — опечатка в команде init-контейнера: `ecko` вместо `echo`, утилита не находится, init падает (`Init:CrashLoopBackOff`), и основной контейнер не стартует.
```bash
kubectl logs fixme -c setup        # sh: ecko: not found
kubectl delete pod fixme
kubectl apply -f solution/fixed.yaml
kubectl wait --for=condition=Ready pod/fixme --timeout=120s
```

## Задание 4. Нативный sidecar
```bash
kubectl apply -f solution/withcar.yaml
kubectl wait --for=condition=Ready pod/withcar --timeout=120s
kubectl get pod withcar -o jsonpath='{.status.initContainerStatuses[0].state}{"\n"}'   # running
```
`logger` объявлен в `initContainers` с `restartPolicy: Always`, поэтому не завершается, а работает рядом с `app` — это нативный sidecar.
