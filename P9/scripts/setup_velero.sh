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

echo "=== [1/4] Configurando credenciales S3 para Velero en OCI Object Storage ==="
cat << 'EOF' > ./credentials-velero
[default]
aws_access_key_id=f1d42c24ce294b258951d8f684e89b40ea6b1b34
aws_secret_access_key=kFZqh2PKH/aSO4qNg3F6O2jk2SwxbsDhai+oabVYztA=
EOF

echo "=== [2/4] Instalando Velero CLI (si no existe) ==="
if ! command -v velero &> /dev/null; then
  echo "Descargando Velero CLI para Linux..."
  mkdir -p "${HOME}/bin"
  curl -fsSL https://github.com/vmware-tanzu/velero/releases/download/v1.14.0/velero-v1.14.0-linux-amd64.tar.gz | tar -xz -C /tmp/
  mv /tmp/velero-v1.14.0-linux-amd64/velero "${HOME}/bin/"
  rm -rf /tmp/velero-v1.14.0-linux-amd64
  chmod +x "${HOME}/bin/velero"
  export PATH="${HOME}/bin:${PATH}"
fi

echo "=== [3/4] Instalando servidor Velero en clúster OKE con OCI Object Storage ==="
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.10.0 \
  --bucket "${BUCKET}" \
  --secret-file ./credentials-velero \
  --backup-location-config "region=${REGION},s3ForcePathStyle=true,s3Url=${S3_URL}" \
  --use-node-agent \
  --wait

rm -f ./credentials-velero

echo "=== [4/4] Creando Schedule programado y Respaldo Inicial de Continuidad ==="
# Programación periódica cada 6 horas con retención de 30 días (720 horas)
velero schedule create sa-platform-scheduled-backup \
  --schedule="0 */6 * * *" \
  --include-namespaces produccion \
  --default-volumes-to-fs-backup \
  --ttl 720h0m0s || true

# Ejecutar respaldo inicial que cubre produccion y kube-system (llave de Sealed Secrets)
echo ">> Ejecutando respaldo inicial verificado (producción y secretos)..."
velero backup create sa-initial-backup \
  --include-namespaces produccion,kube-system \
  --default-volumes-to-fs-backup \
  --wait

echo ""
echo "=== RESUMEN DE RESPALDOS CON VELERO EN OCI ==="
velero backup get
echo ""
velero schedule get
echo ">> Velero configurado exitosamente en Oracle Cloud!"
