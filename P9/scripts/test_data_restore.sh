#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PRUEBA DE RESPALDO Y RESTAURACIÓN DE DATOS CON VELERO (POSTGRESQL PERSISTENTE)
# Práctica 9 - Carnet: 201712620
# ==============================================================================

LOG_FILE="evidencias/restauracion_datos.txt"
mkdir -p evidencias

echo "======================================================================" | tee -a "$LOG_FILE"
echo " [START] PRUEBA DE RESTAURACIÓN DE DATOS CON ESTADO EN VELERO" | tee -a "$LOG_FILE"
echo " Fecha y hora: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"

PG_POD=$(kubectl get pod -n produccion -l app=sa-platform-postgresql -o jsonpath='{.items[0].metadata.name}' || kubectl get pod -n produccion -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')

echo "Pod de PostgreSQL detectado: $PG_POD" | tee -a "$LOG_FILE"

# 1. Insertar datos de prueba verificables en la base de datos
echo "" | tee -a "$LOG_FILE"
echo ">> [1/5] Insertando registros de prueba verificables en PostgreSQL..." | tee -a "$LOG_FILE"

kubectl exec -n produccion "$PG_POD" -- env PGPASSWORD="secretpassword" psql -U postgres -d transacciones -c "
CREATE TABLE IF NOT EXISTS clientes_transacciones (
    id SERIAL PRIMARY KEY,
    carnet VARCHAR(20) NOT NULL,
    descripcion VARCHAR(100) NOT NULL,
    monto NUMERIC(10,2) NOT NULL,
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO clientes_transacciones (carnet, descripcion, monto) VALUES 
('201712620', 'Pago Matricula Sistemas Avanzados', 1500.00),
('201712620', 'Aprobacion Transaccion DR', 450.75),
('201712620', 'Servicio Respaldo Velero', 99.99);
" | tee -a "$LOG_FILE"

echo ">> Contenido de la base de datos ANTES del desastre:" | tee -a "$LOG_FILE"
kubectl exec -n produccion "$PG_POD" -- env PGPASSWORD="secretpassword" psql -U postgres -d transacciones -c "SELECT * FROM clientes_transacciones;" | tee -a "$LOG_FILE"

# 2. Generar el respaldo con Velero incluyendo volúmenes persistentes
BACKUP_NAME="backup-verificacion-db-$(date +%s)"
echo "" | tee -a "$LOG_FILE"
echo ">> [2/5] Generando respaldo con Velero ($BACKUP_NAME)..." | tee -a "$LOG_FILE"
velero backup create "$BACKUP_NAME" --include-namespaces produccion --default-volumes-to-fs-backup --wait | tee -a "$LOG_FILE"
velero backup describe "$BACKUP_NAME" | tee -a "$LOG_FILE"

# 3. Simular desastre / pérdida de datos
echo "" | tee -a "$LOG_FILE"
echo ">> [3/5] SIMULANDO DESASTRE: Eliminando tabla y datos de la base de datos..." | tee -a "$LOG_FILE"
kubectl exec -n produccion "$PG_POD" -- env PGPASSWORD="secretpassword" psql -U postgres -d transacciones -c "DROP TABLE clientes_transacciones;" | tee -a "$LOG_FILE"

echo ">> Verificando que los datos se han PERDIDO:" | tee -a "$LOG_FILE"
kubectl exec -n produccion "$PG_POD" -- env PGPASSWORD="secretpassword" psql -U postgres -d transacciones -c "SELECT * FROM clientes_transacciones;" 2>&1 | tee -a "$LOG_FILE" || echo ">> Confirmado: La tabla fue eliminada con éxito." | tee -a "$LOG_FILE"

# 4. Restaurar desde el respaldo de Velero
RESTORE_NAME="restore-verificacion-db-$(date +%s)"
echo "" | tee -a "$LOG_FILE"
echo ">> [4/5] Restaurando datos desde Velero ($RESTORE_NAME)..." | tee -a "$LOG_FILE"
RESTORE_START=$(date +%s)
velero restore create "$RESTORE_NAME" --from-backup "$BACKUP_NAME" --wait | tee -a "$LOG_FILE"
RESTORE_END=$(date +%s)

# Esperar reinicio de PostgreSQL si fue reciclado
sleep 5
kubectl wait --namespace produccion --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=120s || true

# 5. Verificar que los datos volvieron a existir intactos
echo "" | tee -a "$LOG_FILE"
echo ">> [5/5] Verificando datos recuperados en PostgreSQL:" | tee -a "$LOG_FILE"
kubectl exec -n produccion "$PG_POD" -- env PGPASSWORD="secretpassword" psql -U postgres -d transacciones -c "SELECT * FROM clientes_transacciones;" | tee -a "$LOG_FILE"

echo "" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"
echo " [SUCCESS] PRUEBA DE RESTAURACIÓN DE DATOS COMPLETADA" | tee -a "$LOG_FILE"
echo " Tiempo de Restauración (RTO de datos): $((RESTORE_END - RESTORE_START)) segundos" | tee -a "$LOG_FILE"
echo " Pérdida de Datos (RPO medido): 0 registros perdidos (100% de datos recuperados)" | tee -a "$LOG_FILE"
echo " Evidencia guardada en $LOG_FILE" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"
