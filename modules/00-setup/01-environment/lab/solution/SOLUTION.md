# Решение: Окружение: kind, kubectl, kubeconfig

Все команды — из каталога `lab/` урока, если не сказано иное.

## Задание 1. Кластер готов
Из корня репозитория:
```bash
./env/vm-setup.sh        # только в чистой VM, затем перелогиниться
./env/up.sh
kubectl get nodes        # 3 узла Ready
kubectl version          # Client v1.37.1, Server v1.37.0
kubectl config get-contexts
kubectl create namespace lab-00-01
```
`up.sh` сам переключает kubectl на контекст `kind-k8s-course`. Если проверка пишет, что контекст смотрит в другой кластер: `kubectl config use-context kind-k8s-course`.

Если `kind` или `docker` отвечают `permission denied ... docker.sock`, пользователь уже в группе `docker`, но сессия старая. Перелогиньтесь или выполните одну команду через `sg docker -c '...'`.

## Задание 2. Свой контекст
```bash
kubectl config set-context lab-00-01 \
  --cluster=kind-k8s-course --user=kind-k8s-course --namespace=lab-00-01
kubectl config use-context lab-00-01
kubectl run hello --image=nginx:1.27-alpine
kubectl get pods                       # hello Running — уже в lab-00-01
```
То же одним скриптом: `solution/context.sh`.

Частая ошибка — запустить `kubectl run` **до** переключения контекста: pod окажется в namespace `default`. Проверка это распознаёт. Удалите лишний pod (`kubectl -n default delete pod hello`) и создайте его заново в правильном контексте.

`set-context` и `use-context` меняют только `~/.kube/config`. В кластере появился только pod.

## Задание 3. Починить
Подключение файла поверх основного kubeconfig:
```bash
export KUBECONFIG=~/.kube/config:$PWD/start/kubeconfig-lab.yaml
kubectl config get-contexts      # видны kind-k8s-course, lab-00-01 и course-lab
```
Основной файл стоит первым, поэтому `current-context` берётся из него, а новые записи от `kubectl config set-context` тоже попадут в него.

Проблем две, и видны они по очереди:

1. **`cluster: kind-k8s-cource`** (опечатка). Кластера с таким именем в kubeconfig нет. kubectl не сообщает об этом сразу, а молча идёт на адрес по умолчанию `http://localhost:8080`. В нашем окружении порт `8080` хоста проброшен на порт 80 узла (для Ingress), там никто не отвечает на запросы API, и команда висит почти минуту, а потом падает с `connection reset by peer`. Быстрая диагностика:
   ```bash
   kubectl --context course-lab config view --minify
   # error: cannot locate cluster kind-k8s-cource
   kubectl config get-clusters
   # kind-k8s-course
   ```
2. **`namespace: lab-0001`** (опечатка). После исправления кластера команда работает, но pod не находит: `Error from server (NotFound): namespaces "lab-0001" not found` (а `kubectl --context course-lab get pods` пишет `No resources found in lab-0001 namespace.`). `kubectl get ns` показывает, что namespace называется `lab-00-01`.

Исправленный файл — `solution/kubeconfig-lab.yaml`:
```yaml
contexts:
  - name: course-lab
    context:
      cluster: kind-k8s-course
      user: kind-k8s-course
      namespace: lab-00-01
```
```bash
kubectl --context course-lab get pod hello
```

Почему это работает без сертификатов: при объединении файлов из `KUBECONFIG` контекст из одного файла может ссылаться на кластер и пользователя из другого. Кластер `kind-k8s-course` и пользователь `kind-k8s-course` определены в `~/.kube/config`.

## Задание 4. Как kind связан с вашей машиной
```bash
docker ps --filter label=io.x-k8s.kind.cluster=k8s-course \
  --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
docker port k8s-course-control-plane
# 6443/tcp -> 127.0.0.1:40625   → api-port
# 80/tcp -> 0.0.0.0:8080        → ingress-host-port
```
| Ключ | Ответ | Откуда |
|---|---|---|
| `api-port` | случайный, у автора `40625` | проброс `6443/tcp`; совпадает с портом в `kubectl cluster-info` |
| `node-containers` | `3` | по контейнеру на узел; pod в `docker ps` не видны, они внутри узлов |
| `node-image` | `kindest/node:v1.37.0` | колонка `IMAGE`; тег задаёт версию Kubernetes |
| `ingress-host-port` | `8080` | проброс `80/tcp`, задан в `env/kind-config.yaml` |

Скрипт `solution/answers.sh` собирает ответы автоматически и записывает их в ConfigMap.

`api-port` выбирается случайно при создании кластера, поэтому после `./env/down.sh && ./env/up.sh` он будет другим. Остальные три ответа заданы в `env/kind-config.yaml` и одинаковы у всех.
