#!/usr/bin/env bash
# Создать заготовку урока из шаблонов.
# Пример: ./scripts/new-lesson.sh 02-workloads 03-deployments "Deployments и rollout"
set -euo pipefail
[ $# -eq 3 ] || { echo "Использование: $0 <NN-модуль> <NN-тема> \"Название\""; exit 1; }

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE="$1"; TOPIC="$2"; TITLE="$3"
NS="${MODULE%%-*}-${TOPIC%%-*}"          # 02-workloads + 03-deployments -> 02-03
DIR="$ROOT/modules/$MODULE/$TOPIC"

[ -e "$DIR" ] && { echo "Уже существует: $DIR"; exit 1; }
mkdir -p "$DIR/lab/start" "$DIR/lab/solution"

render() {
  sed -e "s|{{TITLE}}|$TITLE|g" -e "s|{{MODULE}}|$MODULE|g" \
      -e "s|{{TOPIC}}|$TOPIC|g" -e "s|{{NS}}|$NS|g" "$1" > "$2"
}

render "$ROOT/templates/lesson.md"          "$DIR/lesson.md"
render "$ROOT/templates/lab/README.md"      "$DIR/lab/README.md"
render "$ROOT/templates/lab/check.sh"       "$DIR/lab/check.sh"
render "$ROOT/templates/lab/cleanup.sh"     "$DIR/lab/cleanup.sh"
printf '# Решение: %s\n\n' "$TITLE" > "$DIR/lab/solution/SOLUTION.md"
touch "$DIR/lab/start/.gitkeep"
chmod +x "$DIR/lab/check.sh" "$DIR/lab/cleanup.sh"

echo "Создано: modules/$MODULE/$TOPIC (namespace lab-$NS)"
