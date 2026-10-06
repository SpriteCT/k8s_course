# Решение: Services

Все команды — из каталога `lab/`, текущий namespace `lab-02-05`. Задания 1–3 и 5 собраны в `solution/web.yaml`, задание 4 — в `solution/fixed.yaml`.

```bash
kubectl apply -f solution/web.yaml
kubectl rollout status deployment/web --timeout=120s
```

## Задание 1. ClusterIP и доступ по имени
У контейнера порт назван: `containerPort: 80, name: http`. Service `web` без `type` — значит ClusterIP; селектор `app: web`, `targetPort: http`.
```bash
kubectl get svc web                                   # TYPE ClusterIP, есть CLUSTER-IP
kubectl exec client -- wget -qO- http://web | head -4 # страница nginx
```
Именованный `targetPort` развязывает Service и номер порта: поменяется порт в pod — Service править не придётся.

## Задание 2. NodePort наружу
Отдельный Service `web-np` с `type: NodePort` и `nodePort: 30080`. С хоста работает именно 30080, потому что он проброшен с узла control-plane в `env/kind-config.yaml`; любой другой nodePort доступен только по IP узла.
```bash
kubectl get svc web-np            # PORT(S) 80:30080/TCP
curl -s http://localhost:30080 | head -4
```

## Задание 3. Headless-Service
`clusterIP: None` задаётся только при создании, поэтому headless — это новый Service `web-h`, а не правка `web`.
```bash
kubectl exec client -- nslookup web.lab-02-05.svc.cluster.local     # один адрес — ClusterIP
kubectl exec client -- nslookup web-h.lab-02-05.svc.cluster.local   # три адреса — IP pod
```

## Задание 4. Починить Service api
Неисправностей две, и видны они по очереди:
1. **Селектор** `component: backend`, а у pod — `component: api`. Эндпоинтов нет, запрос висит или отбивается:
   ```bash
   kubectl get endpointslices -l kubernetes.io/service-name=api   # ENDPOINTS <unset>
   kubectl get pods --show-labels
   ```
2. **targetPort** `80`, а http-echo слушает `8080`. После правки селектора эндпоинты появляются, но `wget` получает `Connection refused`.

Исправление — `solution/fixed.yaml`: селектор `component: api` и `targetPort: http` (по имени, как в `shop/base.yaml`):
```bash
kubectl apply -f solution/fixed.yaml
kubectl exec client -- wget -qO- http://api      # shop api ok
```
Альтернатива — поменять метки pod под селектор Service — хуже: метки Deployment — часть контракта `shop`, на них опираются другие объекты.

## Задание 5. Свой балансировщик
Service `web-lb` с `type: LoadBalancer`. cloud-provider-kind замечает его, поднимает контейнер-балансировщик (`docker ps --filter name=kindccm`) и записывает его IP в `status.loadBalancer.ingress`:
```bash
kubectl get svc web-lb -w                          # <pending> → 172.18.0.x
curl -s http://$(kubectl get svc web-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/ | head -4
```
Обратите внимание: у `web-lb` тоже выделен nodePort — LoadBalancer надстраивается над NodePort.
