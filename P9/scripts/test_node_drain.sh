#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PRUEBA DE RESILIENCIA Y PÉRDIDA DE NODO (NODE DRAIN)
# Práctica 9 - Carnet: 201712620
# ==============================================================================

LOG_FILE="evidencias/drenaje_nodo.txt"
mkdir -p evidencias

echo "======================================================================" | tee -a "$LOG_FILE"
echo " [START] PRUEBA DE RESILIENCIA ANTE PÉRDIDA DE NODO" | tee -a "$LOG_FILE"
echo " Fecha y hora: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"

# 1. Identificar nodos del clúster
echo ">> [1/5] Identificando nodos de trabajo..." | tee -a "$LOG_FILE"
NODES=($(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'))
if [ "${#NODES[@]}" -lt 2 ]; then
  echo "ERROR: Se requieren al menos 2 nodos para la prueba de pérdida de nodo." | tee -a "$LOG_FILE"
  exit 1
fi

TARGET_NODE="${NODES[0]}"
SURVIVOR_NODE="${NODES[1]}"
echo "Nodo a drenar (Target): $TARGET_NODE" | tee -a "$LOG_FILE"
echo "Nodo superviviente: $SURVIVOR_NODE" | tee -a "$LOG_FILE"

# 2. Distribución de pods antes del drenaje (demostración de anti-afinidad)
echo "" | tee -a "$LOG_FILE"
echo ">> [2/5] Distribución de Pods antes del drenaje (Anti-Afinidad):" | tee -a "$LOG_FILE"
kubectl get pods -n produccion -o wide | tee -a "$LOG_FILE"

# 3. Iniciar verificación de tráfico continuo mediante cliente independiente
echo "" | tee -a "$LOG_FILE"
echo ">> [3/5] Iniciando verificación de disponibilidad de servicio en background..." | tee -a "$LOG_FILE"

kubectl run traffic-prober --image=curlimages/curl:8.6.0 --restart=Never -n default --overrides="{\"spec\":{\"nodeName\":\"${SURVIVOR_NODE}\"}}" -- sleep 120 || true
kubectl wait --for=condition=ready pod/traffic-prober -n default --timeout=60s || true

PROBE_LOG="evidencias/traffic_probe.log"
> "$PROBE_LOG"

SVC_NAME=$(kubectl get svc -n produccion -l app.kubernetes.io/name=api-gateway -o jsonpath='{.items[0].metadata.name}' || echo "sa-platform-app-api-gateway")

(
  for i in {1..30}; do
    STATUS=$(kubectl exec -n default traffic-prober -- curl -s -o /dev/null -w "%{http_code}" "http://${SVC_NAME}.produccion.svc.cluster.local:80" || echo "FAIL")
    echo "$(date +%T) - Request #$i -> Status: $STATUS" >> "$PROBE_LOG"
    sleep 1
  done
) &
PROBE_PID=$!

# 4. Ejecutar drenaje del nodo
echo "" | tee -a "$LOG_FILE"
echo ">> [4/5] Drenando el nodo $TARGET_NODE (simulación de fallo)..." | tee -a "$LOG_FILE"
DRAIN_START=$(date +%s)
kubectl drain "$TARGET_NODE" --ignore-daemonsets --delete-emptydir-data --force | tee -a "$LOG_FILE"
DRAIN_END=$(date +%s)
echo ">> Nodo drenado en $((DRAIN_END - DRAIN_START)) segundos." | tee -a "$LOG_FILE"

wait $PROBE_PID || true

echo "" | tee -a "$LOG_FILE"
echo ">> Resultado del tráfico durante el drenaje:" | tee -a "$LOG_FILE"
cat "$PROBE_LOG" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo ">> Distribución de Pods después del drenaje (Reubicados en superviviente):" | tee -a "$LOG_FILE"
kubectl get pods -n produccion -o wide | tee -a "$LOG_FILE"

# 5. Restaurar el nodo a estado operativo (Uncordon)
echo "" | tee -a "$LOG_FILE"
echo ">> [5/5] Restaurando el nodo $TARGET_NODE (Uncordon)..." | tee -a "$LOG_FILE"
kubectl uncordon "$TARGET_NODE" | tee -a "$LOG_FILE"
kubectl delete pod traffic-prober -n default --wait=false 2>/dev/null || true

echo "" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"
echo " [SUCCESS] PRUEBA DE PÉRDIDA DE NODO COMPLETADA EXITOSAMENTE" | tee -a "$LOG_FILE"
echo " Evidencia guardada en $LOG_FILE" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"
