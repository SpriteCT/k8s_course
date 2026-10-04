# Лабораторная: Окружение: kind, kubectl, kubeconfig

**Namespace:** `lab-00-01` · **Время:** 30–45 мин · **Проверка:** `./check.sh`

В этой лабе вы поднимете учебный кластер, настроите себе контекст, почините чужой kubeconfig и разберётесь, как kind связывает кластер с вашей машиной.

Все команды — из каталога `lab/` этого урока.

## Подготовка
Если инструменты ещё не установлены — в чистой VM выполните из корня репозитория `./env/vm-setup.sh` и перелогиньтесь.

## Задание 1. Кластер готов
На вашей машине должен работать учебный кластер из `env/`:
- 3 узла, все в состоянии `Ready`;
- api-server версии `v1.37.x`, kubectl отличается от него не больше чем на одну minor-версию;
- текущий контекст kubectl указывает на кластер `kind-k8s-course`.

Когда кластер готов, создайте namespace лабы (namespace — «папка» для объектов, подробно в уроке 01-03):
```bash
kubectl create namespace lab-00-01
```

<details><summary>Подсказка 1</summary>

В каталоге `env/` в корне репозитория есть скрипт, который делает почти всё сам.
</details>
<details><summary>Подсказка 2</summary>

`kubectl get nodes`, `kubectl version`, `kubectl config get-contexts`. Если `docker`/`kind` отвечают `permission denied` — см. таблицу ошибок в уроке.
</details>

## Задание 2. Свой контекст
В вашем основном kubeconfig должен быть контекст `lab-00-01`:
- кластер и пользователь — те же, что у контекста `kind-k8s-course`;
- namespace по умолчанию — `lab-00-01`;
- этот контекст — текущий.

Работая в нём, **без** флагов `-n` и `--context` запустите pod `hello` из образа `nginx:1.27-alpine`. Pod — минимальная единица запуска в Kubernetes (подробно в уроке 02-01); создаётся командой `kubectl run <имя> --image=<образ>`. Pod должен оказаться в namespace `lab-00-01` и работать (`Running`).

Файл kubeconfig руками не редактируйте — только командами `kubectl config ...`.

<details><summary>Подсказка 1</summary>

`kubectl config set-context --help`: новый контекст можно собрать из существующих `--cluster` и `--user`.
</details>
<details><summary>Подсказка 2</summary>

Проверить себя: `kubectl config get-contexts` (звёздочка и колонка `NAMESPACE`), `kubectl get pods` без флагов должен показать `hello`.
</details>

## Задание 3. Починить
Коллега прислал вам файл `start/kubeconfig-lab.yaml` с контекстом `course-lab` для работы с этой лабой. Сертификатов в нём нет: он рассчитан на то, что вы подключите его **поверх** своего основного kubeconfig, а не скопируете в него.

1. Подключите файл так, чтобы kubectl видел одновременно контексты из `~/.kube/config` и из `start/kubeconfig-lab.yaml`. Копировать содержимое в `~/.kube/config` нельзя.
2. Исправьте `start/kubeconfig-lab.yaml` так, чтобы команда
   ```bash
   kubectl --context course-lab get pod hello
   ```
   показывала pod `hello` из задания 2. Проблем в файле больше одной.

<details><summary>Подсказка 1</summary>

Нужна переменная окружения, в которой перечисляются файлы kubeconfig через `:`.
</details>
<details><summary>Подсказка 2</summary>

Если команда висит почти минуту — прервите её (Ctrl+C) и выполните `kubectl --context course-lab config view --minify`. Эта команда не ходит в кластер и сразу говорит, чего не хватает.
</details>
<details><summary>Подсказка 3</summary>

Ошибка исчезла, но вместо pod — `NotFound`? Сравните namespace в контексте `course-lab` со списком `kubectl get ns`.
</details>

## Задание 4. Как kind связан с вашей машиной
Выясните с помощью `docker` и `kind` (kubectl здесь почти не поможет) и запишите ответы в ConfigMap `answers` в namespace `lab-00-01`:

| Ключ | Что записать |
|---|---|
| `api-port` | Порт на вашей машине, через который kubectl попадает в api-server (только число) |
| `node-containers` | Сколько Docker-контейнеров запущено для кластера `k8s-course` (число) |
| `node-image` | Образ, из которого запущены контейнеры-узлы, с тегом (вида `репозиторий:тег`) |
| `ingress-host-port` | На какой порт вашей машины проброшен порт `80` узла control-plane (число) |

ConfigMap — объект «ключ → значение» (подробно в уроке 03-01). Создать или обновить его:
```bash
kubectl -n lab-00-01 create configmap answers \
  --from-literal=ключ1=значение1 \
  --from-literal=ключ2=значение2 \
  --dry-run=client -o yaml | kubectl apply -f -
```
Указывайте **все** ключи каждый раз: команда заменяет ConfigMap целиком.

<details><summary>Подсказка 1</summary>

`docker ps` — колонки `IMAGE` и `PORTS`. Кластер kind помечает свои контейнеры: `docker ps --filter label=io.x-k8s.kind.cluster=k8s-course`.
</details>
<details><summary>Подсказка 2</summary>

`docker port k8s-course-control-plane` покажет все пробросы одного контейнера. api-server внутри узла слушает порт `6443`.
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
Скрипт удалит namespace `lab-00-01` и контекст `lab-00-01`, вернёт текущим контекст `kind-k8s-course`. Переменную `KUBECONFIG` из задания 3 уберите сами: `unset KUBECONFIG`. Чтобы пройти задание 3 заново, верните исходный файл: `git checkout -- start/kubeconfig-lab.yaml`.
