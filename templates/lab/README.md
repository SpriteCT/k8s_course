# Лабораторная: {{TITLE}}

**Namespace:** `lab-{{NS}}` · **Время:** 30–60 мин · **Проверка:** `./check.sh`

## Подготовка
```bash
kubectl create namespace lab-{{NS}}
kubectl config set-context --current --namespace=lab-{{NS}}
# при необходимости: kubectl apply -f start/
```

## Задание 1. Воспроизвести
<!-- Результат, которого нужно добиться, а не шаги. -->

<details><summary>Подсказка 1</summary>…</details>
<details><summary>Подсказка 2</summary>…</details>

## Задание 2. Изменить
…

## Задание 3. Починить
Манифест `start/broken.yaml` не работает. Найдите и исправьте причину, не пересоздавая ресурс с нуля.

<details><summary>Подсказка 1</summary>Посмотрите events.</details>

## Задание 4. Спроектировать самому
…

## Проверка
```bash
./check.sh
```

## Уборка
```bash
./cleanup.sh
```
