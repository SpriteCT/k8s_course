# Решение: Probes и graceful shutdown

Все команды — из каталога `lab/`, текущий namespace `lab-02-03`.

## Задание 1. Пробы на pod
```bash
kubectl apply -f solution/web.yaml
kubectl wait --for=condition=Ready pod/web --timeout=120s
kubectl get pod web      # READY 1/1
```
readiness и liveness бьют HTTP на `/` порт 80 — тот, что слушает nginx.

## Задание 2. Readiness и эндпоинты
```bash
kubectl apply -f solution/notready.yaml
sleep 10
kubectl get endpointslices -l kubernetes.io/service-name=web \
  -o jsonpath='{range .items[*].endpoints[*]}{.addresses[0]} {.conditions.ready}{"\n"}{end}'
```
`web` проходит readiness → его адрес `ready=true`, трафик идёт. У `notready` readiness бьёт на закрытый порт 8081 → адрес `ready=false`, kube-proxy его исключает. Контейнер `notready` при этом работает — readiness не перезапускает, только убирает из балансировки.

## Задание 3. Починить liveness
Проблема: `livenessProbe` бьёт на порт 9999, которого нет; проба проваливается, kubelet убивает живой контейнер — растут перезапуски.
```bash
kubectl describe pod api | grep -A2 Liveness    # Liveness probe failed: connection refused
kubectl delete pod api
kubectl apply -f solution/fixed.yaml            # порт пробы = 80
kubectl wait --for=condition=Ready pod/api --timeout=120s
```

## Задание 4. Корректное завершение
```bash
kubectl apply -f solution/graceful.yaml
kubectl get pod graceful -o jsonpath='{.spec.terminationGracePeriodSeconds}{"\n"}'          # 30
kubectl get pod graceful -o jsonpath='{.spec.containers[0].lifecycle.preStop.exec.command}{"\n"}'  # nginx -s quit
```
При удалении pod адрес убирается из эндпоинтов, выполняется `preStop` (`nginx -s quit`), процессу идёт `SIGTERM`, и даётся 30 секунд до `SIGKILL`.
