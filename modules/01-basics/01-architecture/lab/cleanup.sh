#!/usr/bin/env bash
# Откатить всё, что делает лаба: namespace, namespace по умолчанию в контекстах, правки в start/.
set -euo pipefail
NS="lab-01-01"
LAB="$(cd "$(dirname "$0")" && pwd)"

kubectl delete namespace "$NS" --ignore-not-found --wait=true

# Контексты, которым по ходу лабы поставили namespace lab-01-01 (set-context --current),
# иначе они будут смотреть в удалённый namespace.
for ctx in $(kubectl config view -o jsonpath="{range .contexts[?(@.context.namespace==\"$NS\")]}{.name}{\"\n\"}{end}"); do
  kubectl config set-context "$ctx" --namespace=default >/dev/null
  echo "Контекст $ctx: namespace по умолчанию возвращён в default"
done

# Исходный (сломанный) манифест для задания 3
if git -C "$LAB" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$LAB" checkout -- start/
fi

echo "Namespace $NS удалён, start/ восстановлен"
