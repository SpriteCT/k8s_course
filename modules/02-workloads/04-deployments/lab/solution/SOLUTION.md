# Решение: Deployments и rollout

Все команды — из каталога `lab/`, текущий namespace `lab-02-04`.

## Задание 1. Deployment с репликами и requests
```bash
kubectl apply -f solution/web.yaml
kubectl rollout status deployment/web --timeout=120s
kubectl get deploy web          # READY 3/3
kubectl get deploy,rs,pod -l app=web
```
`selector.matchLabels` совпадает с `template.metadata.labels` (`app: web`); у контейнера заданы `requests` и readiness.

## Задание 2. Выкат и откат
```bash
kubectl set image deployment/web web=nginx:1.26-alpine
kubectl rollout status deployment/web --timeout=120s     # дождаться выката
kubectl rollout undo deployment/web                       # откат
kubectl rollout status deployment/web --timeout=120s
kubectl get deploy web -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'   # снова nginx:1.27-alpine
kubectl rollout history deployment/web                    # >= 3 ревизий
```
Каждая смена образа — новый ReplicaSet; откат переключает Deployment на прошлый. Всё это делает `solution/rollout.sh`.

## Задание 3. Починить застрявший выкат
Причина — опечатка в теге: `nginx:1.27-alpne`. Новые pod в `ImagePullBackOff`, выкат не завершается.
```bash
kubectl get pods -l app=api                 # ImagePullBackOff
kubectl set image deployment/api api=nginx:1.27-alpine
# либо: kubectl apply -f solution/fixed.yaml
kubectl rollout status deployment/api --timeout=120s      # 2/2
```
