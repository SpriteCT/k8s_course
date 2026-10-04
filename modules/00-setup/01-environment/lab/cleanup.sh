#!/usr/bin/env bash
# Откатить всё, что делает лаба: namespace, контекст из задания 2,
# namespace по умолчанию в других контекстах, правки в start/.
set -euo pipefail
NS="lab-00-01"
LAB="$(cd "$(dirname "$0")" && pwd)"

kubectl delete namespace "$NS" --ignore-not-found --wait=true

# Контекст из задания 2: сначала уйти с него, потом удалить
kubectl config use-context kind-k8s-course >/dev/null
if kubectl config get-contexts -o name | grep -qx "$NS"; then
  kubectl config delete-context "$NS" >/dev/null
fi

# Контексты, которым по ходу лабы поставили namespace lab-00-01 (например, kind-k8s-course
# через set-context --current), иначе они будут смотреть в удалённый namespace.
# course-lab живёт в start/kubeconfig-lab.yaml и восстанавливается ниже.
for ctx in $(kubectl config view -o jsonpath="{range .contexts[?(@.context.namespace==\"$NS\")]}{.name}{\"\n\"}{end}"); do
  [ "$ctx" = "course-lab" ] && continue
  kubectl config set-context "$ctx" --namespace=default >/dev/null
  echo "Контекст $ctx: namespace по умолчанию возвращён в default"
done

# Исходный (сломанный) kubeconfig-фрагмент для задания 3
if git -C "$LAB" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$LAB" checkout -- start/kubeconfig-lab.yaml
fi

echo "Namespace $NS и контекст $NS удалены, start/ восстановлен, текущий контекст: kind-k8s-course"
case ":${KUBECONFIG:-}:" in
  *kubeconfig-lab.yaml*) echo "В этом терминале задан KUBECONFIG из задания 3 — снимите его: unset KUBECONFIG" ;;
esac
