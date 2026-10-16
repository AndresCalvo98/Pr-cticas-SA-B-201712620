#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PRUEBA DE RECUPERACIÓN CRONOMETRADA (RTO REAL)
# Destrucción y Reconstrucción Total de Día Cero
# Práctica 9 - Carnet: 201712620
# ==============================================================================

LOG_FILE="evidencias/reconstruccion_cronometrada.txt"
mkdir -p evidencias

echo "======================================================================" | tee -a "$LOG_FILE"
echo " [START] PRUEBA DE RECUPERACIÓN CRONOMETRADA ANTE DESASTRE TOTAL" | tee -a "$LOG_FILE"
echo " Marca de tiempo: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# FASE 1: Destrucción Total del Entorno
echo "" | tee -a "$LOG_FILE"
echo ">> [FASE 1] SIMULANDO DESASTRE CATASTRÓFICO: Destruyendo clúster y cargas..." | tee -a "$LOG_FILE"
T_DESTROY_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DESTROY_EPOCH_START=$(date +%s)
echo "Inicio de destrucción: $T_DESTROY_START" | tee -a "$LOG_FILE"

cd "${SCRIPT_DIR}/terraform"
terraform destroy -auto-approve | tee -a "${SCRIPT_DIR}/$LOG_FILE"

T_DESTROY_END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DESTROY_EPOCH_END=$(date +%s)
echo "Fin de destrucción: $T_DESTROY_END" | tee -a "$LOG_FILE"
echo "Tiempo de destrucción: $((DESTROY_EPOCH_END - DESTROY_EPOCH_START)) segundos" | tee -a "$LOG_FILE"

# FASE 2: Reconstrucción Automatizada desde Cero (Bootstrap de Día Cero)
echo "" | tee -a "$LOG_FILE"
echo ">> [FASE 2] INICIANDO RECONSTRUCCIÓN AUTOMATIZADA CON BOOTSTRAP DE DÍA CERO..." | tee -a "$LOG_FILE"
T_REBUILD_START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REBUILD_EPOCH_START=$(date +%s)
echo "Inicio de Reconstrucción (T0): $T_REBUILD_START" | tee -a "$LOG_FILE"

cd "${SCRIPT_DIR}"
./bootstrap.sh | tee -a "$LOG_FILE"

T_REBUILD_END=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REBUILD_EPOCH_END=$(date +%s)
RTO_SECONDS=$((REBUILD_EPOCH_END - REBUILD_EPOCH_START))
RTO_MINUTES=$((RTO_SECONDS / 60))

echo "" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"
echo " [RESULTADOS DE LA PRUEBA DE RTO REAL]" | tee -a "$LOG_FILE"
echo " Tiempo Inicial de Desastre (T0): $T_REBUILD_START" | tee -a "$LOG_FILE"
echo " Tiempo de Sistema 100% Operativo (T1): $T_REBUILD_END" | tee -a "$LOG_FILE"
echo " RTO Real Medido: ${RTO_SECONDS} segundos (${RTO_MINUTES} minutos y $((RTO_SECONDS % 60)) segundos)" | tee -a "$LOG_FILE"
echo " Estado de Nodos y Pods:" | tee -a "$LOG_FILE"
kubectl get nodes | tee -a "$LOG_FILE"
kubectl get pods -n produccion | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"
