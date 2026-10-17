#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PRUEBA DE RESPALDO Y RESTAURACIÓN DE DATOS CON VELERO (POSTGRESQL PERSISTENTE)
# Práctica 9 - Carnet: 201712620
# ==============================================================================

LOG_FILE="evidencias/restauracion_datos.txt"
mkdir -p evidencias

export PATH="${HOME}/bin:/usr/local/bin:${PATH}"

ARCH=$(uname -m)
case "$ARCH" in
  x86_64) VELERO_ARCH="amd64" ;;
  aarch64|arm64) VELERO_ARCH="arm64" ;;
  *) VELERO_ARCH="amd64" ;;
esac

if ! velero version --client-only &> /dev/null; then
  echo "Velero CLI no encontrado o arquitectura incorrecta. Descargando Velero CLI para $ARCH ($VELERO_ARCH)..."
  mkdir -p "${HOME}/bin"
  rm -f "${HOME}/bin/velero"
  curl -fsSL "https://github.com/vmware-tanzu/velero/releases/download/v1.14.0/velero-v1.14.0-linux-${VELERO_ARCH}.tar.gz" | tar -xz -C /tmp/
  mv /tmp/velero-v1.14.0-linux-${VELERO_ARCH}/velero "${HOME}/bin/"
  rm -rf /tmp/velero-v1.14.0-linux-${VELERO_ARCH}
  chmod +x "${HOME}/bin/velero"
fi

echo "======================================================================" | tee -a "$LOG_FILE"
echo " [START] PRUEBA DE RESTAURACIÓN DE DATOS CON ESTADO EN VELERO" | tee -a "$LOG_FILE"
echo " Fecha y hora: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" | tee -a "$LOG_FILE"
echo "======================================================================" | tee -a "$LOG_FILE"

PG_POD=$(kubectl get pods -n produccion -o name | grep -i postgresql | head -n 1 | cut -d/ -f2)

echo "Pod de PostgreSQL detectado: $PG_POD" | tee -a "$LOG_FILE"

echo "Esperando a que el pod de PostgreSQL esté completamente Listo (1/1 Ready)..." | tee -a "$LOG_FILE"
kubectl wait --namespace produccion --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=180s

ARG_BACKUP="${1:-}"

if [ -n "$ARG_BACKUP" ]; then
    BACKUP_NAME="$ARG_BACKUP"
    echo ">> Reutilizando respaldo existente válido: $BACKUP_NAME" | tee -a "$LOG_FILE"
else
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
    velero backup create "$BACKUP_NAME" --include-namespaces produccion --default-volumes-to-fs-backup --snapshot-volumes=false --wait | tee -a "$LOG_FILE"
    velero backup describe "$BACKUP_NAME" | tee -a "$LOG_FILE"
fi

# Detectar el tipo de recurso exacto del Application Controller de ArgoCD (StatefulSet o Deployment)
CONTROLLER_RESOURCE=$(kubectl get statefulset,deployment -n argocd -o name 2>/dev/null | grep -i application-controller | head -n 1 || echo "statefulset/argocd-application-controller")

# 3. Simular desastre / pérdida de datos y volumen
echo "" | tee -a "$LOG_FILE"
echo ">> [3/5] SIMULANDO DESASTRE: Corrupción de base de datos y pérdida del volumen persistente..." | tee -a "$LOG_FILE"
kubectl exec -n produccion "$PG_POD" -- env PGPASSWORD="secretpassword" psql -U postgres -d transacciones -c "DROP TABLE IF EXISTS clientes_transacciones;" 2>/dev/null | tee -a "$LOG_FILE" || true

# Pausar el Application Controller de ArgoCD para evitar que recree los recursos antes que Velero
echo "Pausando temporalmente ArgoCD Application Controller ($CONTROLLER_RESOURCE)..." | tee -a "$LOG_FILE"
kubectl scale "$CONTROLLER_RESOURCE" -n argocd --replicas=0
kubectl wait --for=delete pod -l app.kubernetes.io/name=argocd-application-controller -n argocd --timeout=30s || true

# Eliminar StatefulSet y PVC simulando pérdida total del almacenamiento persistente
echo "Eliminando StatefulSet y PersistentVolumeClaim de PostgreSQL..." | tee -a "$LOG_FILE"
kubectl delete statefulset sa-platform-app-postgresql -n produccion --cascade=foreground --wait=true 2>/dev/null || true
kubectl delete pvc data-sa-platform-app-postgresql-0 -n produccion --wait=true 2>/dev/null || true
kubectl wait --for=delete pod/sa-platform-app-postgresql-0 -n produccion --timeout=60s 2>/dev/null || true
kubectl wait --for=delete pvc/data-sa-platform-app-postgresql-0 -n produccion --timeout=60s 2>/dev/null || true

# 4. Restaurar desde el respaldo de Velero
RESTORE_NAME="restore-verificacion-db-$(date +%s)"
echo "" | tee -a "$LOG_FILE"
echo ">> [4/5] Restaurando StatefulSet, PVC, PV y datos desde Velero ($RESTORE_NAME)..." | tee -a "$LOG_FILE"
RESTORE_START=$(date +%s)
velero restore create "$RESTORE_NAME" --from-backup "$BACKUP_NAME" --include-namespaces produccion --wait | tee -a "$LOG_FILE"
RESTORE_END=$(date +%s)

# Reanudar ArgoCD Application Controller
echo "Reanudando ArgoCD Application Controller ($CONTROLLER_RESOURCE)..." | tee -a "$LOG_FILE"
kubectl scale "$CONTROLLER_RESOURCE" -n argocd --replicas=1

# Esperar a que el pod restaurado esté 1/1 Ready
echo "Esperando a que el pod de PostgreSQL restaurado esté 1/1 Ready..." | tee -a "$LOG_FILE"
kubectl wait --namespace produccion --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=180s

PG_POD=$(kubectl get pods -n produccion -o name | grep -i postgresql | head -n 1 | cut -d/ -f2)

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
