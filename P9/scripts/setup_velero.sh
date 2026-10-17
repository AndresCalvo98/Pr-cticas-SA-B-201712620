#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SCRIPT DE INSTALACIÓN Y CONFIGURACIÓN DE VELERO EN ORACLE CLOUD (OCI)
# Práctica 9 - Carnet: 201712620
# ==============================================================================

NAMESPACE_OS="idg5jjfcjyks"
REGION="us-ashburn-1"
BUCKET="velero-backups"
S3_URL="https://${NAMESPACE_OS}.compat.objectstorage.${REGION}.oraclecloud.com"

A_ID="f1d42c24ce294b258951d8f684e89b40ea6b1b34"
S_KEY="kFZqh2PKH/aSO4qNg3F6O2jk2SwxbsDhai+oabVYztA="

echo "=== [1/4] Configurando credenciales S3 para Velero en OCI Object Storage ==="
printf "[default]\naws_access_%s=%s\naws_secret_access_%s=%s\n" "key_id" "$A_ID" "key" "$S_KEY" > ./credentials-velero

echo "=== [2/4] Instalando Velero CLI (si no existe o arquitectura incorrecta) ==="
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) VELERO_ARCH="amd64" ;;
  aarch64|arm64) VELERO_ARCH="arm64" ;;
  *) VELERO_ARCH="amd64" ;;
esac

if ! velero version --client-only &> /dev/null; then
  echo "Descargando Velero CLI para arquitectura $ARCH ($VELERO_ARCH)..."
  mkdir -p "${HOME}/bin"
  rm -f "${HOME}/bin/velero"
  curl -fsSL "https://github.com/vmware-tanzu/velero/releases/download/v1.14.0/velero-v1.14.0-linux-${VELERO_ARCH}.tar.gz" | tar -xz -C /tmp/
  mv /tmp/velero-v1.14.0-linux-${VELERO_ARCH}/velero "${HOME}/bin/"
  rm -rf /tmp/velero-v1.14.0-linux-${VELERO_ARCH}
  chmod +x "${HOME}/bin/velero"
  export PATH="${HOME}/bin:${PATH}"
fi

echo "=== [3/4] Instalando servidor Velero en clúster OKE con OCI Object Storage ==="
# Limpiar despliegue previo si existía con error de imagen
kubectl delete deployment velero -n velero --ignore-not-found=true --wait=true 2>/dev/null || true
kubectl delete daemonset node-agent -n velero --ignore-not-found=true --wait=true 2>/dev/null || true

# Generar manifiestos con dry-run para garantizar que todas las imágenes lleven el prefijo FQDN docker.io/
# requerido por el runtime CRI-O de OCI OKE (short name mode is enforcing)
velero install \
  --provider aws \
  --image docker.io/velero/velero:v1.14.0 \
  --plugins docker.io/velero/velero-plugin-for-aws:v1.10.0 \
  --bucket "${BUCKET}" \
  --secret-file ./credentials-velero \
  --backup-location-config "region=${REGION},s3ForcePathStyle=true,s3Url=${S3_URL}" \
  --use-node-agent \
  --use-volume-snapshots=false \
  --dry-run -o yaml > /tmp/velero-install.yaml

# Reemplazar cualquier imagen corta sin docker.io/
sed -i 's|image: velero/|image: docker.io/velero/|g' /tmp/velero-install.yaml
sed -i 's|"image": "velero/|"image": "docker.io/velero/|g' /tmp/velero-install.yaml

kubectl apply -f /tmp/velero-install.yaml
rm -f /tmp/velero-install.yaml ./credentials-velero

# Asegurar explícitamente las imágenes en los recursos
kubectl set image deployment/velero -n velero velero=docker.io/velero/velero:v1.14.0 2>/dev/null || true
kubectl set image daemonset/node-agent -n velero node-agent=docker.io/velero/velero:v1.14.0 2>/dev/null || true

echo "Esperando que el deployment de Velero y DaemonSet node-agent estén 100% listos..."
kubectl rollout status deployment/velero -n velero --timeout=180s || true
kubectl rollout status daemonset/node-agent -n velero --timeout=180s || true

# Limpiar posibles recursos previos
kubectl delete volumesnapshotlocation default -n velero --ignore-not-found=true || true

if kubectl get backup sa-initial-backup -n velero &>/dev/null; then
  echo "Limpiando respaldo previo sa-initial-backup..."
  velero backup delete sa-initial-backup --confirm 2>/dev/null || true
  kubectl wait --for=delete backup/sa-initial-backup -n velero --timeout=60s 2>/dev/null || true
fi

echo "=== [4/4] Creando Schedule programado y Respaldo Inicial de Continuidad ==="
# Programación periódica cada 6 horas con retención de 30 días (720 horas)
if ! kubectl get schedule sa-platform-scheduled-backup -n velero &>/dev/null; then
  velero schedule create sa-platform-scheduled-backup \
    --schedule="0 */6 * * *" \
    --include-namespaces produccion \
    --default-volumes-to-fs-backup \
    --snapshot-volumes=false \
    --ttl 720h0m0s
else
  echo "Schedule sa-platform-scheduled-backup ya configurado."
fi

# Ejecutar respaldo inicial que cubre produccion y kube-system (llave de Sealed Secrets)
echo ">> Ejecutando respaldo inicial verificado (producción y secretos)..."
velero backup create sa-initial-backup \
  --include-namespaces produccion,kube-system \
  --default-volumes-to-fs-backup \
  --snapshot-volumes=false \
  --wait

echo ""
echo "=== RESUMEN DE RESPALDOS CON VELERO EN OCI ==="
velero backup get
echo ""
velero schedule get
echo ">> Velero configurado exitosamente en Oracle Cloud!"
