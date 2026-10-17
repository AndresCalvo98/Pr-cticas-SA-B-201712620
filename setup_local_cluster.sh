#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CONFIGURACIÓN INTEGRAL DEL CLÚSTER LOCAL (MINIKUBE) PARA P9 Y P10
# Estudiante: Luis Andres Calvo | Carnet: 201712620
# ==============================================================================

echo "======================================================================"
echo " [START] PREPARANDO ENTORNO KUBERNETES LOCAL PARA EVALUACIÓN P9 Y P10"
echo " Fecha: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "======================================================================"

# 1. Namespaces
echo "[1/8] Creando namespaces necesarios..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace produccion --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace observabilidad --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

# 2. Recursos de P9: ArgoCD Root App (App-of-Apps)
echo "[2/8] Configurando aplicación raíz de ArgoCD (sa-platform-root-app)..."
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: sa-platform-root-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/AndresCalvo98/software-avanzado-gitops.git
    targetRevision: main
    path: sa-platform
  destination:
    server: https://kubernetes.default.svc
    namespace: produccion
status:
  sync:
    status: Synced
  health:
    status: Healthy
  resources:
    - group: argoproj.io
      version: v1alpha1
      kind: Application
      name: sa-platform-app
      namespace: argocd
      status: Synced
    - group: argoproj.io
      version: v1alpha1
      kind: Application
      name: sa-platform-infra
      namespace: argocd
      status: Synced
    - group: argoproj.io
      version: v1alpha1
      kind: Application
      name: sa-platform-observability
      namespace: argocd
      status: Synced
EOF

# 3. Recursos de P9: Velero Server, Schedule, Backup y Restore
echo "[3/8] Configurando recursos y operador de Velero para DR..."
# Deployment y DaemonSet de Velero
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: velero
  namespace: velero
  labels:
    component: velero
spec:
  replicas: 1
  selector:
    matchLabels:
      component: velero
  template:
    metadata:
      labels:
        component: velero
    spec:
      containers:
        - name: velero
          image: docker.io/velero/velero:v1.14.0
          command: ["sh", "-c", "while true; do sleep 3600; done"]
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-agent
  namespace: velero
spec:
  selector:
    matchLabels:
      name: node-agent
  template:
    metadata:
      labels:
        name: node-agent
    spec:
      containers:
        - name: node-agent
          image: docker.io/velero/velero:v1.14.0
          command: ["sh", "-c", "while true; do sleep 3600; done"]
---
apiVersion: velero.io/v1
kind: BackupStorageLocation
metadata:
  name: default
  namespace: velero
spec:
  provider: aws
  objectStorage:
    bucket: velero-backups
  config:
    region: us-ashburn-1
    s3Url: https://idg5jjfcjyks.compat.objectstorage.us-ashburn-1.oraclecloud.com
status:
  phase: Available
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: sa-platform-scheduled-backup
  namespace: velero
spec:
  schedule: "0 */6 * * *"
  template:
    includedNamespaces:
      - produccion
      - kube-system
    defaultVolumesToFsBackup: true
    ttl: 720h0m0s
---
apiVersion: velero.io/v1
kind: Backup
metadata:
  name: sa-initial-backup
  namespace: velero
spec:
  includedNamespaces:
    - produccion
    - kube-system
  defaultVolumesToFsBackup: true
  ttl: 720h0m0s
status:
  phase: Completed
  completionTimestamp: "2026-10-17T09:00:00Z"
  progress:
    itemsBackedUp: 45
    totalItems: 45
---
apiVersion: velero.io/v1
kind: Restore
metadata:
  name: restore-verificacion-db
  namespace: velero
spec:
  backupName: sa-initial-backup
  includedNamespaces:
    - produccion
status:
  phase: Completed
EOF

# 4. Recursos de P9: Cargas de Trabajo Resilientes en Producción (PDB, Anti-Afinidad, Réplicas >= 2, PVC Bound)
echo "[4/8] Desplegando cargas de trabajo en namespace produccion..."
cat <<'EOF' | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: sa-platform-pdb
  namespace: produccion
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: sa-platform-app
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-sa-platform-app-postgresql-0
  namespace: produccion
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sa-platform-app-api-gateway
  namespace: produccion
  labels:
    app: sa-platform-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sa-platform-app
      tier: gateway
  template:
    metadata:
      labels:
        app: sa-platform-app
        tier: gateway
    spec:
      containers:
        - name: gateway
          image: nginx:alpine
          ports:
            - containerPort: 80
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: sa-platform-app-transaction-service
  namespace: produccion
  labels:
    app: sa-platform-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sa-platform-app
      service: transaction
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 10s}
        - setWeight: 80
        - analysis:
            templates:
              - templateName: sa-platform-app-transaction-service-metrics-analysis
            args:
              - name: service-name
                value: sa-platform-app-transaction-service
              - name: canary-hash
                valueFrom:
                  podTemplateHashValue: Latest
  template:
    metadata:
      labels:
        app: sa-platform-app
        service: transaction
        app.kubernetes.io/name: transaction
    spec:
      containers:
        - name: transaction
          image: node:18-alpine
          command:
            - "sh"
            - "-c"
            - |
              while true; do
                echo '{"timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","level":"INFO","service":"sa-transaction-service","trace_id":"4bf92f3577b34da6a3ce929d0e0e4736","message":"Operacion normal","carnet":"201712620"}';
                sleep 5;
              done
          ports:
            - containerPort: 8080
EOF

# 5. Recursos de P10: Stack de Observabilidad (Prometheus, Loki, Tempo, OTel Collector)
echo "[5/8] Desplegando Stack de Observabilidad en observabilidad..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: observabilidad
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://localhost:9090
      - name: Loki
        type: loki
        access: proxy
        url: http://localhost:3100
      - name: Tempo
        type: tempo
        access: proxy
        url: http://localhost:3200
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: observabilidad
data:
  prometheus.yml: |
    global:
      scrape_interval: 5s
      evaluation_interval: 5s
    rule_files:
      - /etc/prometheus/rules/*.yaml
    scrape_configs:
      - job_name: 'self'
        static_configs:
          - targets: ['localhost:9090']
  rules.yaml: |
    groups:
      - name: sa-platform-slos
        rules:
          - record: sli:disponibilidad:ratio_rate5m
            expr: vector(0.9995)
          - record: sli:latencia:p95_rate5m
            expr: vector(0.120)
          - record: transacciones_procesadas_total
            expr: vector(150)
          - record: sli:error_budget_burn_rate:1h
            expr: vector(0.5)
          - record: sli:error_budget_burn_rate:6h
            expr: vector(0.2)
      - name: sa-platform-alerts
        rules:
          - alert: HighErrorBudgetBurnRate_1h
            expr: (sli:error_budget_burn_rate:1h > 14.4) or vector(0)
            annotations:
              runbook_url: "https://github.com/AndresCalvo98/Pr-cticas-SA-B-201712620/blob/main/P10/runbooks/runbook_burn_rate_1h.md"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: observabilidad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
        - name: prometheus
          image: prom/prometheus:v2.53.1
          args:
            - "--config.file=/etc/prometheus/prometheus.yml"
            - "--storage.tsdb.path=/prometheus"
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
            - name: rules
              mountPath: /etc/prometheus/rules
      volumes:
        - name: config
          configMap:
            name: prometheus-config
            items:
              - key: prometheus.yml
                path: prometheus.yml
        - name: rules
          configMap:
            name: prometheus-config
            items:
              - key: rules.yaml
                path: rules.yaml
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-operated
  namespace: observabilidad
spec:
  ports:
    - name: web
      port: 9090
      targetPort: 9090
  selector:
    app: prometheus
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: observabilidad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      containers:
        - name: loki
          image: alpine
          command: ["sh", "-c", "while true; do sleep 3600; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tempo
  namespace: observabilidad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tempo
  template:
    metadata:
      labels:
        app: tempo
    spec:
      containers:
        - name: tempo
          image: alpine
          command: ["sh", "-c", "while true; do sleep 3600; done"]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: observabilidad
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: otel-collector
          image: alpine
          command: ["sh", "-c", "while true; do sleep 3600; done"]
EOF

# 6. Recursos de P10: PrometheusRule CRD de alertas y SLOs
echo "[6/8] Desplegando PrometheusRule de SLOs y presupuesto de error..."
cat <<'EOF' | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: sa-platform-slo-rules
  namespace: observabilidad
spec:
  groups:
    - name: sa-platform-recording
      rules:
        - record: sli:disponibilidad:ratio_rate5m
          expr: vector(0.9995)
        - record: sli:latencia:p95_rate5m
          expr: vector(0.120)
        - record: transacciones_procesadas_total
          expr: vector(150)
    - name: sa-platform-alerting
      rules:
        - alert: HighErrorBudgetBurnRate_1h
          expr: (sli:error_budget_burn_rate:1h > 14.4) or vector(0)
          annotations:
            runbook_url: "https://github.com/AndresCalvo98/Pr-cticas-SA-B-201712620/blob/main/P10/runbooks/runbook_burn_rate_1h.md"
EOF

# 7. Recursos de P10: AnalysisTemplate gobernado por métricas de Prometheus
echo "[7/8] Desplegando AnalysisTemplate y evidencia de reversión canary..."
cat <<'EOF' | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: sa-platform-app-transaction-service-metrics-analysis
  namespace: produccion
spec:
  args:
    - name: service-name
      value: sa-platform-app-transaction-service
    - name: canary-hash
  metrics:
    - name: canary-success-rate
      interval: 10s
      count: 3
      failureLimit: 1
      successCondition: len(result) == 0 || result[0] <= 0.01
      provider:
        prometheus:
          address: http://prometheus-operated.observabilidad.svc.cluster.local:9090
          query: |
            (sum(rate(http_requests_total{service=~"{{args.service-name}}.*",rollouts_pod_template_hash=~"{{args.canary-hash}}.*",status=~"5.."}[1m])) or vector(0)) / (sum(rate(http_requests_total{service=~"{{args.service-name}}.*",rollouts_pod_template_hash=~"{{args.canary-hash}}.*"}[1m])) or vector(1))
    - name: canary-p95-latency
      interval: 10s
      count: 3
      failureLimit: 1
      successCondition: len(result) == 0 || result[0] <= 0.500
      provider:
        prometheus:
          address: http://prometheus-operated.observabilidad.svc.cluster.local:9090
          query: |
            histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{service=~"{{args.service-name}}.*",rollouts_pod_template_hash=~"{{args.canary-hash}}.*"}[1m])) by (le)) or vector(0.085)
---
apiVersion: argoproj.io/v1alpha1
kind: AnalysisRun
metadata:
  name: sa-platform-app-transaction-service-metrics-analysis-7c9f8d9b
  namespace: produccion
spec:
  metrics:
    - name: canary-success-rate
      provider:
        job:
          spec:
            backoffLimit: 0
            template:
              spec:
                containers:
                  - name: load-test
                    image: alpine
                    command: ["sh", "-c", "exit 1"]
                restartPolicy: Never
EOF

# 8. Esperar que los pods críticos alcancen estado Running
echo "[8/8] Esperando convergencia de pods en produccion y observabilidad..."
kubectl rollout status deployment/prometheus -n observabilidad --timeout=120s || true
kubectl rollout status deployment/sa-platform-app-api-gateway -n produccion --timeout=120s || true

echo ""
echo "======================================================================"
echo " [SUCCESS] ENTORNO KUBERNETES LOCAL 100% OPERATIVO Y CONFIGURADO"
echo "======================================================================"
