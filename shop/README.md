# Сквозное приложение `shop`

Эталон учебного приложения курса. Это **единственный источник правды** о том, из чего состоит `shop`: уроки опираются на него и показывают, что добавляет модуль, а не переизобретают приложение.

## Состав
Три яруса, все на публичных образах с фиксированными тегами (настоящий код не нужен — важны объекты Kubernetes, а не бизнес-логика):

| Компонент | Образ | Роль | Порт |
|---|---|---|---|
| `frontend` | `nginx:1.27-alpine` | веб-ярус, точка входа | 80 |
| `api` | `hashicorp/http-echo:1.0` | бэкенд, отвечает фиксированной строкой | 8080 |
| `redis` | `redis:7.4-alpine` | хранилище состояния | 6379 |

Каждый объект помечен лейблами `app.kubernetes.io/part-of: shop` и `app.kubernetes.io/component: <компонент>` — по ним удобно выбирать ресурсы и писать `check.sh`.

## Что это НЕ
`base.yaml` — намеренно голый базовый вариант: Deployment + Service на каждый ярус, без requests/limits, probes, конфигурации, securityContext, сети и хранилища. Всё это приложение получает по ходу курса — см. таблицу «Сквозное приложение `shop`» в [`SYLLABUS.md`](../SYLLABUS.md). Поэтому `base.yaml` не следует применять «как в проде»: это стартовая точка, а финальный харденинг собирается в модуле 12.

## Запуск вручную
```bash
kubectl create namespace shop
kubectl apply -f shop/base.yaml -n shop
kubectl -n shop rollout status deploy/frontend
# проверка связности из временного pod:
kubectl -n shop run probe --rm -i --restart=Never --image=busybox:1.36 -- \
  sh -c 'wget -qO- http://api; nc -z redis 6379 && echo " redis ok"'
kubectl delete namespace shop
```

Проверено на кластере из `env/` (Kubernetes v1.37): манифесты применяются без ошибок, `api` отвечает `shop api ok`, `redis` доступен по TCP.
