# Программа курса

Статусы: `todo` → `draft` → `reviewed` → `done`. Каталог урока: `modules/<модуль>/<тема>/`.

## 00-setup — Окружение
| Тема | Содержание | Статус |
|---|---|---|
| 01-environment | Docker, kind, kubectl, k9s; подъём кластера из `env/`; kubeconfig и контексты | todo |

## 01-basics — Основы
| Тема | Содержание | Статус |
|---|---|---|
| 01-architecture | Control plane (api-server, etcd, scheduler, controller-manager), узлы (kubelet, kube-proxy, container runtime); декларативная модель и reconcile loop | draft |
| 02-api-and-kubectl | Объекты и API-группы, `apiVersion/kind/metadata/spec/status`, `get/describe/explain/apply/delete`, `-o yaml/jsonpath`, `--dry-run` | todo |
| 03-namespaces-labels | Namespaces, labels и selectors, annotations | todo |

## 02-workloads — Рабочие нагрузки
| Тема | Содержание | Статус |
|---|---|---|
| 01-pods | Pod, жизненный цикл, multi-container, init- и sidecar-контейнеры, restartPolicy | todo |
| 02-probes | liveness / readiness / startup probes, graceful shutdown | todo |
| 03-deployments | ReplicaSet, Deployment, rolling update, rollback, стратегии | todo |
| 04-daemonsets-statefulsets | DaemonSet, StatefulSet (без хранилища — оно в модуле 05) | todo |
| 05-jobs | Job, CronJob, параллелизм, backoffLimit | todo |

## 03-config — Конфигурация
| Тема | Содержание | Статус |
|---|---|---|
| 01-configmaps | ConfigMap: env, volume, обновление конфигурации | todo |
| 02-secrets | Secret: типы, монтирование, ограничения безопасности | todo |

## 04-networking — Сеть
| Тема | Содержание | Статус |
|---|---|---|
| 01-services | ClusterIP, NodePort, LoadBalancer, headless; Endpoints/EndpointSlices | todo |
| 02-dns | CoreDNS, имена сервисов и pod, отладка DNS | todo |
| 03-ingress-gateway | Ingress (классический подход) и Gateway API; TLS | todo |
| 04-network-policies | NetworkPolicy: default deny, ingress/egress правила (нужен CNI с поддержкой политик) | todo |

## 05-storage — Хранилище
| Тема | Содержание | Статус |
|---|---|---|
| 01-volumes | emptyDir, hostPath, projected | todo |
| 02-pv-pvc | PV, PVC, StorageClass, динамическое выделение, access modes, reclaim policy | todo |
| 03-stateful-storage | StatefulSet + volumeClaimTemplates (redis для `shop`) | todo |

## 06-scheduling — Планирование и ресурсы
| Тема | Содержание | Статус |
|---|---|---|
| 01-resources | requests/limits, QoS-классы, OOMKilled, LimitRange, ResourceQuota | todo |
| 02-placement | nodeSelector, affinity/anti-affinity, taints/tolerations, topologySpreadConstraints | todo |
| 03-availability | PodDisruptionBudget, PriorityClass, drain/cordon | todo |

## 07-security — Безопасность
| Тема | Содержание | Статус |
|---|---|---|
| 01-rbac | ServiceAccount, Role/ClusterRole, Bindings, `kubectl auth can-i` | todo |
| 02-pod-security | securityContext, Pod Security Standards / Admission | todo |

## 08-operations — Наблюдаемость, масштабирование, отладка
| Тема | Содержание | Статус |
|---|---|---|
| 01-observability | logs, events, metrics-server, `kubectl top`, `kubectl debug` | todo |
| 02-autoscaling | HPA, основы VPA и Cluster Autoscaler | todo |
| 03-troubleshooting | Систематическая отладка: Pending, CrashLoopBackOff, ImagePullBackOff, сервис не отвечает | todo |

## 09-packaging — Пакетирование
| Тема | Содержание | Статус |
|---|---|---|
| 01-kustomize | base/overlays, patches, генераторы | todo |
| 02-helm | Чарты, values, шаблоны, релизы; свой чарт для `shop` | todo |

## 10-ecosystem — Расширение и экосистема
| Тема | Содержание | Статус |
|---|---|---|
| 01-crd-operators | CustomResourceDefinition, идея оператора, установка готового оператора | todo |
| 02-gitops | Argo CD: приложение из git-репозитория, синхронизация, откат | todo |
| 03-monitoring | Prometheus + Grafana (kube-prometheus-stack), ServiceMonitor | todo |

## 11-cluster-admin — Администрирование кластера (опционально, уровень CKA)
| Тема | Содержание | Статус |
|---|---|---|
| 01-kubeadm | Установка кластера kubeadm, обновление версии | todo |
| 02-etcd-backup | Бэкап и восстановление etcd | todo |

## 12-final — Финальный проект
| Тема | Содержание | Статус |
|---|---|---|
| 01-final-project | Развернуть `shop` «как в продакшене»: Helm/Kustomize, Gateway, NetworkPolicy, RBAC, HPA, PDB, мониторинг, GitOps. Проверка — `check.sh` | todo |
