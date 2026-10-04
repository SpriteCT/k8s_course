# Лабораторная: API и kubectl

**Namespace:** `lab-01-02` · **Время:** 30–45 мин · **Проверка:** `./check.sh`

В этой лабе вы создадите объект декларативно из сгенерированной заготовки, научитесь доставать из кластера ровно нужные данные, почините манифест, который сервер отвергает, и получите доступ к pod без Service.

## Подготовка
```bash
kubectl create namespace lab-01-02
kubectl config set-context --current --namespace=lab-01-02
```

Ответы записывайте в ConfigMap `answers` (объект «ключ → значение», подробно в уроке 03-01):
```bash
kubectl create configmap answers \
  --from-literal=ключ=значение \
  --dry-run=client -o yaml | kubectl apply -f -
```
Указывайте **все** ключи каждый раз — команда заменяет ConfigMap целиком.

## Задание 1. Создать объект декларативно
В namespace `lab-01-02` должен работать (`Running`) pod `web` из образа `nginx:1.27-alpine` с меткой `app=web` и контейнером, слушающим порт 80.

Не пишите манифест с нуля: сгенерируйте заготовку императивной командой с `--dry-run=client -o yaml`, сохраните в файл и примените его через `apply`.

<details><summary>Подсказка 1</summary>

`kubectl run web --image=nginx:1.27-alpine --port=80 --labels=app=web --dry-run=client -o yaml > pod.yaml`, затем `kubectl apply -f pod.yaml`.
</details>
<details><summary>Подсказка 2</summary>

Проверьте заготовку до применения: `kubectl apply -f pod.yaml --dry-run=server`.
</details>

## Задание 2. Достать данные из кластера
Не читая весь YAML глазами, узнайте значения и запишите их в ConfigMap `answers`:

| Ключ | Что записать |
|---|---|
| `api-version` | значение `apiVersion` у pod `web` |
| `pod-node` | имя узла, на котором работает `web` |
| `image` | образ контейнера `web` |
| `raw-path` | REST-путь, по которому api-server отдаёт объект pod `web` (вида `/api/v1/namespaces/.../pods/web`) |

<details><summary>Подсказка 1</summary>

`kubectl get pod web -o jsonpath='{.spec.nodeName}'`, `...'{.spec.containers[0].image}'`, `...'{.apiVersion}'`.
</details>
<details><summary>Подсказка 2</summary>

REST-путь можно подсмотреть флагом `-v=6`: `kubectl get pod web -v=6`. Core-объекты обслуживаются под `/api/v1/...`.
</details>

## Задание 3. Починить манифест
Примените `start/broken.yaml` — api-server его отвергает по нескольким причинам сразу. Добейтесь, чтобы в namespace появился и работал (`Running`) pod `fixed` на образе `nginx:1.27-alpine`. Проблем больше одной.

```bash
kubectl apply -f start/broken.yaml
```

<details><summary>Подсказка 1</summary>

Проверяйте правки через `kubectl apply -f start/broken.yaml --dry-run=server` — он даёт те же ошибки, но ничего не создаёт.
</details>
<details><summary>Подсказка 2</summary>

Разберите ошибки по очереди: неверная версия API (сверьте с `kubectl api-resources`), незнакомое поле (`kubectl explain pod.spec`), неверный тип значения порта.
</details>

## Задание 4. Доступ без Service
Убедитесь, что `web` реально отдаёт страницу. Service в курсе ещё не было — используйте проброс порта или запрос изнутри кластера. Это задание проверяется автоматически (проверка сама обращается к pod).

<details><summary>Подсказка 1</summary>

`kubectl port-forward pod/web 8080:80`, затем в другом терминале `curl -I http://localhost:8080`. Либо запрос из временного pod по IP pod: `kubectl get pod web -o jsonpath='{.status.podIP}'`.
</details>

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
