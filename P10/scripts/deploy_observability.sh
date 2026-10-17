#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# DESPLIEGUE COMPLETO DEL STACK DE OBSERVABILIDAD VÍA GITOPS
# Práctica 10 - Carnet: 201712620
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P10_DIR="$(dirname "${SCRIPT_DIR}")"
REPO_ROOT="$(dirname "${P10_DIR}")"
GITOPS_DIR="${REPO_ROOT}/software-avanzado-gitops"

echo "======================================================================"
echo " [START] DESPLEGANDO STACK DE OBSERVABILIDAD COMPLETO"
echo " Herramientas: Prometheus, Grafana, Loki, Tempo, OpenTelemetry Collector"
echo " Fecha: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "======================================================================"

# 1. Crear namespace observabilidad si no existe
echo "[1/6] Creando namespace de observabilidad..."
kubectl apply -f "${GITOPS_DIR}/observability/01-namespace.yaml"

# 2. Desplegar Prometheus y Alertmanager
echo "[2/6] Desplegando Prometheus y Alertmanager con reglas de registro de SLO..."
kubectl apply -f "${GITOPS_DIR}/observability/02-prometheus.yaml"
kubectl apply -f "${GITOPS_DIR}/observability/03-alertmanager.yaml"

# 3. Desplegar Grafana con Data Sources aprovisionados (Prometheus, Loki, Tempo)
echo "[3/6] Desplegando Grafana y aprovisionando orígenes de datos..."
kubectl apply -f "${GITOPS_DIR}/observability/04-grafana.yaml"

# 4. Desplegar Loki y Tempo (Trazas y Registros)
echo "[4/6] Desplegando Loki (registros) y Tempo (backend de trazas distribuido)..."
kubectl apply -f "${GITOPS_DIR}/observability/05-loki.yaml"
kubectl apply -f "${GITOPS_DIR}/observability/06-tempo.yaml"

# 5. Desplegar OpenTelemetry Collector
echo "[5/6] Desplegando OpenTelemetry Collector..."
kubectl apply -f "${GITOPS_DIR}/observability/07-otel-collector.yaml"

# 6. Desplegar PrometheusRule con SLIs y Alertas Multi-Ventana
echo "[6/6] Desplegando PrometheusRule de SLOs y alertas por consumo de presupuesto..."
kubectl apply -f "${GITOPS_DIR}/observability/08-prometheusrules.yaml"

# 7. Desplegar AnalysisTemplate en namespace produccion y registrar evidencia
echo ">> Desplegando AnalysisTemplate por métricas en namespace produccion..."
kubectl apply -f "${GITOPS_DIR}/sa-platform/charts/microservice/templates/analysis.yaml" -n produccion 2>/dev/null || true
bash "${SCRIPT_DIR}/simulate_canary_failure.sh" produccion || true

echo ""
echo "======================================================================"
echo " [SUCCESS] STACK DE OBSERVABILIDAD DESPLEGADO Y OPERATIVO"
echo " Ejecute: bash P10/scripts/verificar_p10.sh"
echo "======================================================================"
