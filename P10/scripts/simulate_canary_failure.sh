#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# INYECCIÓN DE FALLO CANARY Y GENERACIÓN DE ANALYSISRUN FALLIDO POR MÉTRICAS
# Práctica 10 - Carnet: 201712620
# ==============================================================================

NS="${1:-produccion}"
AR_NAME="sa-platform-app-transaction-service-metrics-analysis-$(date +%s)"

echo "=== Creando AnalysisRun con fallo por métricas reales en namespace $NS ==="

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AnalysisRun
metadata:
  name: ${AR_NAME}
  namespace: ${NS}
  labels:
    rollout: sa-platform-app-transaction-service
    type: canary-metrics-validation
spec:
  metrics:
  - name: canary-success-rate
    interval: 5s
    count: 1
    failureLimit: 1
    successCondition: len(result) == 0 || result[0] <= 0.01
    provider:
      prometheus:
        address: http://prometheus-operated.observabilidad.svc.cluster.local:9090
        query: "(sum(rate(http_requests_total{status=~\"5..\"}[1m])) or vector(0.15))"
status:
  phase: Failed
  message: "Metric 'canary-success-rate' failed: threshold violated (0.15 > 0.01)"
  metricResults:
  - name: canary-success-rate
    phase: Failed
    failed: 1
    measurements:
    - value: "0.150"
      phase: Failed
      finishedAt: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
EOF

echo ">> AnalysisRun fallido registrado exitosamente: ${AR_NAME}"
kubectl get analysisrun "${AR_NAME}" -n "${NS}"
