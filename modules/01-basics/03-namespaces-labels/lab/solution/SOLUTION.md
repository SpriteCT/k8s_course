# Решение: Namespaces, labels, annotations

Все команды — из каталога `lab/`, текущий namespace `lab-01-03`.

## Задание 1. Разложить по меткам
```bash
kubectl run web-1   --image=nginx:1.27-alpine -l app=shop,tier=frontend,env=prod
kubectl run web-2   --image=nginx:1.27-alpine -l app=shop,tier=frontend,env=dev
kubectl run api-1   --image=nginx:1.27-alpine -l app=shop,tier=api,env=prod
kubectl run cache-1 --image=nginx:1.27-alpine -l app=shop,tier=cache
kubectl get pods --show-labels
```

## Задание 2. Выбрать группами
```bash
kubectl get pods -l app=shop,tier=frontend --no-headers | wc -l   # frontend-count = 2
kubectl get pods -l app=shop,env=prod      --no-headers | wc -l   # prod-count     = 2
kubectl get pods -l 'app=shop,!env'        --no-headers | wc -l   # no-env-count   = 1 (cache-1)
```
`!env` выбирает pod без ключа `env`; у `cache-1` его нет. Ограничение `app=shop` отсекает pod `front-x` из задания 3, у которого `app=web`. Скрипт `solution/pods.sh` делает задания 1, 2 и 4 целиком.

## Задание 3. Починить связь по селектору
Проблема — опечатка в метке pod: `tier: frontnend` вместо `frontend`, поэтому `selector` Service (`tier=frontend`) его не находит, и у Service нет эндпоинтов.
```bash
kubectl get svc shop-front -o jsonpath='{.spec.selector}'   # app=shop,tier=frontend
kubectl get pod front-x --show-labels                       # tier=frontnend  <-- опечатка
kubectl label pod front-x tier=frontend --overwrite         # починка на месте
kubectl get endpoints shop-front                            # теперь есть адрес pod
```
Эквивалентно — применить исправленный `solution/fixed.yaml` (pod нужно пересоздать, т.к. метку мы меняем, а не spec). Любой путь, где метки pod совпадают со всеми парами селектора Service, засчитывается.

## Задание 4. Аннотация
```bash
kubectl annotate pod api-1 owner=team-shop
kubectl get pod api-1 -o jsonpath='{.metadata.annotations.owner}'
```
Аннотация хранит данные, по ней не выбирают — в отличие от метки.
