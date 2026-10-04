# Решение: Контейнер изнутри

Все команды — из каталога `lab/`, текущий namespace `lab-02-01`.

## Задание 1. Два контейнера в одном pod
```bash
kubectl apply -f solution/shared.yaml
kubectl wait --for=condition=Ready pod/shared --timeout=120s
kubectl get pod shared        # READY 2/2
```
`client` получает `command: sleep 3600`, иначе busybox завершился бы сразу и попал в CrashLoopBackOff.

## Задание 2. Общая сеть и факты
```bash
kubectl exec shared -c client -- wget -qO- http://localhost   # страница nginx
kubectl get pod shared -o jsonpath='{.status.podIP}'          # один IP на pod
```
`client` достаёт `server` по `localhost`, потому что контейнеры pod делят network namespace. Ответы (`containers=2`, `pod-ip=<IP>`) записывает `solution/answers.sh`.

## Задание 3. Один pod вместо двух
В `start/broken.yaml` это два **отдельных** pod. У разных pod разные сетевые namespace, поэтому `localhost` в `cli` указывает на сам `cli`, где никто не слушает, — связи нет. «Соединить» два pod сетью по `localhost` нельзя; нужно собрать их в один pod.
```bash
kubectl delete pod srv cli --ignore-not-found
kubectl apply -f solution/paired.yaml
kubectl wait --for=condition=Ready pod/paired --timeout=120s
kubectl exec paired -c client -- wget -qO- http://localhost   # теперь страница nginx
```

## Задание 4. Урезать права
```bash
kubectl apply -f solution/dropped.yaml
kubectl get pod dropped -o jsonpath='{.status.phase}{"\n"}'   # Running
kubectl get pod dropped -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop}{"\n"}'  # ["ALL"]
```
Под root привязка к порту 80 не требует `NET_BIND_SERVICE`, поэтому nginx работает и без единой capability. В проде так и делают: отбирают всё, возвращают нужное точечно (подробно 07-03).
