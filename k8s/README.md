# Kubernetes деплой Petio

## Структура

```
k8s/
├── base/
│   ├── namespaces.yml      # petio + monitoring namespaces
│   └── secrets.example.yml # шаблон секретов (скопировать в secrets.yml и заполнить — secrets.yml в .gitignore)
├── apps/
│   ├── backend.yml         # Backend (2 реплики, rolling update)
│   ├── triton.yml          # Triton Inference Server
│   ├── moderation.yml      # Moderation API
│   └── ingress.yml         # Внешний доступ (Traefik/Nginx)
├── data/
│   └── postgres.yml        # PostgreSQL (StatefulSet + PVC)
└── monitoring/
    ├── prometheus.yml       # Prometheus + конфиг
    ├── grafana.yml          # Grafana + datasource
    └── elk.yml              # Elasticsearch + Kibana + Filebeat
```

## Что где живёт

```
Namespace: petio                    Namespace: monitoring
├── backend (Deployment x2)         ├── prometheus (Deployment)
├── postgres (StatefulSet)          ├── grafana (Deployment)
├── triton (Deployment)             ├── elasticsearch (StatefulSet)
├── moderation-api (Deployment)     ├── kibana (Deployment)
└── petio-secrets (Secret)          └── filebeat (DaemonSet)
```

## Установка k3s (на сервере)

```bash
# 1. Установить k3s (лёгкий Kubernetes, включает Traefik ingress)
curl -sfL https://get.k3s.io | sh -

# 2. Проверить что работает
sudo kubectl get nodes
# NAME     STATUS   ROLES                  AGE   VERSION
# server   Ready    control-plane,master   30s   v1.29.x+k3s1

# 3. Скопировать kubeconfig для удобства (без sudo)
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

## Деплой

```bash
# Порядок важен: namespaces → secrets → data → monitoring → apps

# 1. Namespaces
kubectl apply -f k8s/base/namespaces.yml

# 2. Секреты (⚠️ скопируй secrets.example.yml → secrets.yml и подставь реальные значения)
cp k8s/base/secrets.example.yml k8s/base/secrets.yml
kubectl apply -f k8s/base/secrets.yml

# 3. База данных (подождать пока postgres будет Ready)
kubectl apply -f k8s/data/postgres.yml
kubectl -n petio wait --for=condition=ready pod -l app=postgres --timeout=60s

# 4. Мониторинг
kubectl apply -f k8s/monitoring/prometheus.yml
kubectl apply -f k8s/monitoring/grafana.yml
kubectl apply -f k8s/monitoring/elk.yml

# 5. ML-сервисы (triton долго стартует — качает модели)
kubectl apply -f k8s/apps/triton.yml
kubectl apply -f k8s/apps/moderation.yml

# 6. Backend
kubectl apply -f k8s/apps/backend.yml

# 7. Ingress (внешний доступ)
kubectl apply -f k8s/apps/ingress.yml
```

## Проверка

```bash
# Все поды
kubectl get pods -A

# Логи бэкенда
kubectl -n petio logs -l app=backend -f

# Логи конкретного пода
kubectl -n petio logs backend-xxxxx-yyyyy -f

# Статус деплоймента
kubectl -n petio get deployments

# Описание пода (если не стартует — покажет причину)
kubectl -n petio describe pod <pod-name>
```

## Обновление бэкенда (деплой новой версии)

```bash
# 1. Собрать новый образ
docker build -t registry.example.com/petio-backend:v1.2.3 ./backend
docker push registry.example.com/petio-backend:v1.2.3

# 2. Обновить image в кластере (rolling update, zero-downtime)
kubectl -n petio set image deployment/backend backend=registry.example.com/petio-backend:v1.2.3

# 3. Следить за раскаткой
kubectl -n petio rollout status deployment/backend

# 4. Откатить если что-то не так
kubectl -n petio rollout undo deployment/backend
```

## Доступ к сервисам для отладки

```bash
# Grafana (localhost:3000)
kubectl -n monitoring port-forward svc/grafana 3000:3000

# Kibana (localhost:5601)
kubectl -n monitoring port-forward svc/kibana 5601:5601

# Prometheus (localhost:9090)
kubectl -n monitoring port-forward svc/prometheus 9090:9090

# Backend напрямую (localhost:8080)
kubectl -n petio port-forward svc/backend 8080:8080
```

## Масштабирование

```bash
# Добавить реплики бэкенда
kubectl -n petio scale deployment/backend --replicas=3

# Посмотреть нагрузку на поды
kubectl -n petio top pods
```
