# Курс по Kubernetes

Практический курс: каждый урок = теория + лабораторная работа с автопроверкой.

## Структура

```
k8s-course/
├── CLAUDE.md            # правила для Claude: как писать уроки и задания
├── SYLLABUS.md          # программа курса и статус каждой темы
├── env/                 # учебный кластер (kind) — общий для всех лаб
├── templates/           # шаблоны урока и лабораторной
├── scripts/new-lesson.sh  # создать заготовку урока из шаблона
└── modules/
    └── 02-workloads/
        └── 03-deployments/
            ├── lesson.md          # теория
            └── lab/
                ├── README.md      # задание
                ├── start/         # стартовые манифесты (могут быть с ошибками)
                ├── solution/      # эталонное решение
                ├── check.sh       # автопроверка: exit 0 = выполнено
                └── cleanup.sh     # удалить всё, что создала лаба
```

## Как работать

1. Поднять кластер: `./env/up.sh` (нужны Docker, kind, kubectl). В чистой Linux-VM (Ubuntu 24.04 или Debian 12/13) их ставит `./env/vm-setup.sh`.
2. Создать заготовку урока: `./scripts/new-lesson.sh 02-workloads 03-deployments "Deployments и rollout"`.
3. Попросить Claude: «Напиши урок 02-workloads/03-deployments по SYLLABUS.md».
4. Пройти лабу и проверить: `./modules/02-workloads/03-deployments/lab/check.sh`.
5. Отметить статус темы в `SYLLABUS.md`.

Каждая лаба работает в своём namespace (`lab-<модуль>-<урок>`), поэтому лабы не мешают друг другу.
