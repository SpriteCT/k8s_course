# Программа курса

Практический курс по Kubernetes с уклоном в безопасность и эксплуатацию. Рассчитан на инженера, который знает Linux, shell и Docker, но Kubernetes видит впервые, и которому важны логирование, модель угроз, атаки на кластер и защита.

Статусы: `todo` → `draft` → `reviewed` → `done`. Каталог урока: `modules/<модуль>/<тема>/`.

Каждый урок — теория (`lesson.md`) + лаба с автопроверкой (`lab/check.sh`). Во всех лабах есть задание «сломай и почини», а в модуле 07 и далее — ещё и «атака → детект → защита».

## Окружение
Всё на локальном kind из `env/` (1 control-plane + 2 worker, Kubernetes зафиксирован в `env/kind-config.yaml`). Часть тем требует подготовки сверх базового кластера — она делается заранее скриптами в `env/`, а не посреди урока:

| Что нужно | Для тем | Как даём |
|---|---|---|
| Аудит-лог API (audit policy + extraMounts) | 01-01, 08-01 | вариант конфига `env/kind-audit.yaml` |
| NetworkPolicy | 04-04, 08-02 | штатный kindnet применяет политики — проверено, доп. CNI не нужен |
| LoadBalancer | 02-05 | `cloud-provider-kind` (локальная замена облаку) |
| Ingress/Gateway-контроллер | 04-03 | проброс портов уже в `kind-config.yaml` + установка контроллера скриптом |
| Одноразовый кластер для атак | 08-02 | `./env/down.sh && ./env/up.sh` — атаки воспроизводятся не на кластере с `shop` |
| metrics-server | 09-01, 09-03 | `env/metrics-server.sh` (с `--kubelet-insecure-tls`) |
| Loki + promtail/alloy | 09-02 | установка Helm-чартом в начале урока |
| Kyverno | 07-04 | установка в начале урока |
| Trivy / cosign / Falco | модуль 08 | установка в начале соответствующего урока |
| Отдельные ВМ (kubeadm) | 13-01 | честно: в kind не делается, нужны Multipass/Vagrant |

Теоретические темы, которые на kind не показать вживую (VPA, Cluster Autoscaler), помечены в уроках как теоретические.

## Сквозное приложение `shop`
Небольшой веб-сервис `shop` (frontend + api + redis) обрастает возможностями от модуля к модулю, и финал — сборка уже пройденного, а не новое задание:

| Модуль | Что получает `shop` |
|---|---|
| 02 | Deployment’ы frontend/api, базовый Service, минимальные requests |
| 03 | конфигурация в ConfigMap, пароли в Secret |
| 04 | DNS-имена, Ingress/Gateway, NetworkPolicy между ярусами |
| 05 | redis на StatefulSet с постоянным томом |
| 06 | requests/limits, QoS, PDB, анти-аффинити реплик |
| 07 | least-privilege RBAC, restricted Pod Security, admission-политики |
| 08 | `shop` под аудитом; его образы сканируются и подписываются; на него пишутся runtime-правила; на нём же отрабатываются атаки и детект |
| 09 | метрики, HPA для api |
| 10 | упаковка в Helm/Kustomize |
| 11 | выкатка через Argo CD, мониторинг в Grafana |
| 12 | полный прод-вариант с харденингом |

---

## 00-setup — Окружение
**После модуля:** есть рабочий кластер, вы понимаете, куда и от чьего имени ходит `kubectl`.

| Тема | Содержание | Статус |
|---|---|---|
| 01-environment | Docker, kind, kubectl, k9s; подъём кластера из `env/`; kubeconfig и контексты | reviewed |

## 01-basics — Основы
**После модуля:** читаете и создаёте любой объект, понимаете декларативную модель и жизненный цикл объекта в API.
**Пререквизиты:** 00-setup.

| Тема | Содержание | Статус |
|---|---|---|
| 01-architecture | Control plane (api-server, etcd, scheduler, controller-manager), узлы (kubelet, kube-proxy, runtime); декларативная модель и reconcile loop; owner references, finalizers, garbage collection; где проходят границы доверия | reviewed |
| 02-api-and-kubectl | Объекты и API-группы, `apiVersion/kind/metadata/spec/status`; `get/describe/explain/apply/delete`, `-o yaml/jsonpath`, `--dry-run`; `port-forward`/`exec`/`logs` как первый доступ к приложению; каждый вызов `kubectl` — это запрос к API (мостик к аудиту) | done |
| 03-namespaces-labels | Namespaces как граница, labels и selectors, annotations | reviewed |

## 02-workloads — Рабочие нагрузки
**После модуля:** запускаете приложение, держите N реплик, обновляете без простоя и можете достучаться до сервиса внутри кластера.
**Пререквизиты:** 01-basics.

| Тема | Содержание | Статус |
|---|---|---|
| 01-containers | Что такое контейнер изнутри: namespaces, cgroups, capabilities; что pod делит между контейнерами (network/IPC, опц. PID), pause-контейнер. Фундамент для probes, securityContext и побега из контейнера | reviewed |
| 02-pods | Pod, жизненный цикл, multi-container, init- и sidecar-контейнеры, restartPolicy; Downward API; хуки postStart/preStop | reviewed |
| 03-probes | liveness / readiness / startup probes; graceful shutdown; readiness показываем через Endpoints (почему под исключается из балансировки) | reviewed |
| 04-deployments | ReplicaSet, Deployment, rolling update, rollback, стратегии; здесь же вводим минимальные requests в примеры `shop` | reviewed |
| 05-services | ClusterIP, NodePort, headless; Endpoints/EndpointSlices; LoadBalancer через `cloud-provider-kind`. Service перенесён сюда, чтобы к приложению можно было обратиться сразу | todo |
| 06-daemonsets-jobs | DaemonSet; Job, CronJob, параллелизм, backoffLimit. (StatefulSet перенесён в модуль 05, где есть хранилище) | todo |

## 03-config — Конфигурация
**После модуля:** выносите настройки и секреты из образа и понимаете, почему Secret сам по себе не защита.
**Пререквизиты:** 02-workloads.

| Тема | Содержание | Статус |
|---|---|---|
| 01-configmaps | ConfigMap: env, volume, обновление конфигурации | todo |
| 02-secrets | Secret: типы, монтирование; ограничения (base64 ≠ шифрование); шифрование etcd at rest; обзор External Secrets / Sealed Secrets | todo |

## 04-networking — Сеть
**После модуля:** понимаете, как пакет идёт от pod к pod, публикуете сервис наружу по имени и ограничиваете трафик между ярусами.
**Пререквизиты:** 02-workloads/05-services.

| Тема | Содержание | Статус |
|---|---|---|
| 01-cluster-networking | Модель сети: у каждого pod свой маршрутизируемый IP; CNI (kindnet) и cluster/pod/service CIDR; как kube-proxy реализует ClusterIP через iptables; путь пакета между узлами. Фундамент для DNS, Ingress и NetworkPolicy | todo |
| 02-dns | CoreDNS, FQDN сервисов и pod, search-домены, отладка DNS | todo |
| 03-ingress-gateway | Ingress (классика) и Gateway API; TLS; установка контроллера в kind | todo |
| 04-network-policies | NetworkPolicy: default-deny, ingress/egress; сегментация как защита от бокового перемещения (kindnet применяет политики — проверено) | todo |

## 05-storage — Хранилище
**После модуля:** даёте приложению постоянный том и понимаете жизненный цикл данных.
**Пререквизиты:** 02-workloads.

| Тема | Содержание | Статус |
|---|---|---|
| 01-volumes | emptyDir, hostPath (и почему hostPath опасен), projected | todo |
| 02-pv-pvc | PV, PVC, StorageClass, динамическое выделение, access modes, reclaim policy | todo |
| 03-stateful-storage | StatefulSet + headless Service + volumeClaimTemplates: стабильные имена и тома (redis для `shop`) | todo |

## 06-scheduling — Планирование и ресурсы
**После модуля:** управляете размещением pod и защищаете узлы от исчерпания ресурсов.
**Пререквизиты:** 02-workloads. Нужны все 3 узла.

| Тема | Содержание | Статус |
|---|---|---|
| 01-resources | requests/limits, QoS-классы, OOMKilled, LimitRange, ResourceQuota | todo |
| 02-placement | nodeSelector, affinity/anti-affinity, taints/tolerations, topologySpreadConstraints | todo |
| 03-availability | PodDisruptionBudget, PriorityClass, drain/cordon | todo |

## 07-security — Защита кластера
**После модуля:** выдаёте минимальные права, запускаете контейнеры без лишних привилегий и навязываете правила через admission.
**Пререквизиты:** 01-basics, 02-workloads, 03-config, 04-networking, 06-scheduling.

| Тема | Содержание | Статус |
|---|---|---|
| 01-authentication | Как API узнаёт, кто вы: клиентские сертификаты, bearer-токены, ServiceAccount-токены, обзор OIDC; CA кластера и TLS между компонентами; аутентификация kubelet. Аутентификация (кто) против авторизации (что можно) | todo |
| 02-rbac | ServiceAccount, Role/ClusterRole, Bindings, `kubectl auth can-i`; токены SA; пути эскалации привилегий через права | todo |
| 03-pod-security | securityContext, Linux capabilities, seccomp, runAsNonRoot, readOnlyRootFilesystem; Pod Security Standards/Admission; что включает побег из контейнера (privileged, hostPath, hostPID) | todo |
| 04-admission-policy | ValidatingAdmissionPolicy (CEL), идея admission-вебхуков; Kyverno как policy-engine (запрет latest, обязательные requests, запрет privileged) | todo |

## 08-threat-detection — Атаки, аудит и детектирование
**После модуля:** читаете аудит-лог, воспроизводите типовые атаки на кластер, видите их следы и закрываете их защитой из модуля 07.
**Пререквизиты:** весь модуль 07. Наступательные лабы выполняются на **одноразовом** кластере (`./env/down.sh && ./env/up.sh`), а не на том, где живёт `shop`.
**Этика:** материал для защиты собственных/учебных кластеров. Все атаки — только в локальной лабе.

| Тема | Содержание | Статус |
|---|---|---|
| 01-audit-logging | Аудит API в kind: audit policy, уровни, что и зачем логировать; чтение и фильтрация событий; базовые линии «нормального» поведения | todo |
| 02-attacks | Модель угроз, MITRE ATT&CK for Containers; воспроизведение в изолированном кластере: открытый kubelet/API, злоупотребление токеном SA, побег из privileged-контейнера через hostPath, кража секретов, боковое перемещение. Для каждой атаки — след в аудите (из 08-01) и перекрытие средствами модуля 07 | todo |
| 03-supply-chain | Скан образов (Trivy), SBOM/KBOM; подпись образов (cosign) и проверка подписи на admission; запрет неподписанных и уязвимых образов | todo |
| 04-runtime-security | Falco (modern eBPF): детект поведения в рантайме (shell в контейнере, чтение `/etc/shadow`, неожиданный egress); как срабатывание превращается в алерт; ловим атаки из 08-02 вживую | todo |

## 09-operations — Наблюдаемость, масштабирование, отладка
**После модуля:** видите, что происходит с нагрузкой, масштабируете её и системно чините инциденты.
**Пререквизиты:** 02-workloads, 06-scheduling.

| Тема | Содержание | Статус |
|---|---|---|
| 01-observability | logs, events, metrics-server, `kubectl top`, `kubectl debug` (ephemeral containers) | todo |
| 02-logging | Логи pod эфемерны и умирают вместе с pod — почему нужна агрегация; архитектура сбора логов на узле; централизованный сбор (Loki + promtail/alloy), запрос логов по лейблам; что отправлять в агрегатор, а что в аудит (08-01) | todo |
| 03-autoscaling | HPA на метриках; VPA и Cluster Autoscaler — обзорно/теоретически (на kind не демонстрируются) | todo |
| 04-troubleshooting | Систематическая отладка: Pending, CrashLoopBackOff, ImagePullBackOff, OOMKilled, сервис не отвечает; сведение приёмов из всех модулей | todo |

## 10-packaging — Пакетирование
**После модуля:** собираете конфигурацию `shop` в переиспользуемый пакет.
**Пререквизиты:** 03-config, 04-networking.

| Тема | Содержание | Статус |
|---|---|---|
| 01-kustomize | base/overlays, patches, генераторы | todo |
| 02-helm | Чарты, values, шаблоны, релизы; свой чарт для `shop` | todo |

## 11-ecosystem — Расширение и экосистема
**После модуля:** ставите операторы, выкатываете из git и собираете метрики.
**Пререквизиты:** 07-security (CRD/RBAC), 10-packaging.

| Тема | Содержание | Статус |
|---|---|---|
| 01-crd-operators | CustomResourceDefinition, идея оператора, установка готового оператора | todo |
| 02-gitops | Argo CD: приложение из git, синхронизация, откат; дрейф и его обнаружение | todo |
| 03-monitoring | Prometheus + Grafana (kube-prometheus-stack), ServiceMonitor; дашборд и алерт для `shop` | todo |

## 12-final — Финальный проект
**После модуля:** разворачиваете `shop` «как в продакшене» с харденингом.
**Пререквизиты:** все предыдущие модули.

| Тема | Содержание | Статус |
|---|---|---|
| 01-final-project | `shop` в прод-виде: Helm/Kustomize, Gateway + TLS, NetworkPolicy default-deny, least-privilege RBAC, restricted Pod Security, HPA, PDB, скан образов на admission, аудит и runtime-детект, мониторинг, GitOps. Проверка — `check.sh` (функциональность) + security-check (харденинг) | todo |

## 13-cluster-admin — Администрирование кластера (опционально, уровень CKA)
Вне основной линии: отдельный навык для тех, кто хочет понимать кластер «снизу». Требует ВМ.

| Тема | Содержание | Статус |
|---|---|---|
| 01-kubeadm | Установка кластера kubeadm, обновление версии (нужны отдельные ВМ, не kind) | todo |
| 02-etcd-backup | Бэкап и восстановление etcd; связь с шифрованием etcd из 03-02 | todo |
