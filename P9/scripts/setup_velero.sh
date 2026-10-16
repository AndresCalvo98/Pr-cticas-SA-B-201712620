#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# SCRIPT DE INSTALACIÓN Y CONFIGURACIÓN DE VELERO EN AZURE
# Práctica 9 - Carnet: 201712620
# ==============================================================================

RESOURCE_GROUP="rg-sa-p9-dr"
STORAGE_ACCOUNT="sasp9tfstate10854"
CONTAINER="velero-backups"

echo "=== [1/4] Obteniendo credenciales y detalles de suscripción en Azure ==="
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)

# Crear o reutilizar Service Principal para Velero
echo "=== [2/4] Configurando Service Principal para Velero ==="
SP_NAME="velero-sa-p9-sp"
AZURE_CLIENT_SECRET=$(az ad sp create-for-rbac --name "$SP_NAME" --role "Contributor" --scopes "/subscriptions/${AZURE_SUBSCRIPTION_ID}" --query 'password' -o tsv || true)

if [ -z "$AZURE_CLIENT_SECRET" ]; then
  echo "Reasignando credencial a Service Principal existente..."
  AZURE_CLIENT_SECRET=$(az ad sp credential reset --name "$SP_NAME" --query 'password' -o tsv)
fi

AZURE_CLIENT_ID=$(az ad sp list --display-name "$SP_NAME" --query '[0].appId' -o tsv)

# Crear archivo de credenciales temporal
cat << EOF > ./credentials-velero
AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID}
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
AZURE_CLIENT_SECRET=${AZURE_CLIENT_SECRET}
AZURE_RESOURCE_GROUP=${RESOURCE_GROUP}
AZURE_CLOUD_NAME=AzurePublicCloud
EOF

echo "=== [3/4] Instalando Velero CLI (si no existe) e instalando servidor en clúster ==="
if ! command -v velero &> /dev/null; then
  echo "Descargando Velero CLI para Linux..."
  mkdir -p ~/bin
  curl -fsSL https://github.com/vmware-tanzu/velero/releases/download/v1.14.0/velero-v1.14.0-linux-amd64.tar.gz | tar -xz
  mv velero-v1.14.0-linux-amd64/velero ~/bin/
  rm -rf velero-v1.14.0-linux-amd64
  export PATH="${HOME}/bin:${PATH}"
fi

# Instalar Velero en el clúster AKS con el plugin de Azure y node-agent para respaldar PVCs
velero install \
  --provider azure \
  --plugins velero/velero-plugin-for-microsoft-azure:v1.10.0 \
  --bucket "${CONTAINER}" \
  --secret-file ./credentials-velero \
  --backup-location-config "resourceGroup=${RESOURCE_GROUP},storageAccount=${STORAGE_ACCOUNT}" \
  --snapshot-location-config "apiTimeout=5m,resourceGroup=${RESOURCE_GROUP}" \
  --use-node-agent \
  --wait

rm -f ./credentials-velero

echo "=== [4/4] Creando Schedule programado de Velero (Requisito 3.3 / 2.3) ==="
# Programación periódica cada 6 horas con retención de 30 días (720 horas)
velero schedule create sa-platform-scheduled-backup \
  --schedule="0 */6 * * *" \
  --include-namespaces produccion \
  --default-volumes-to-fs-backup \
  --ttl 720h0m0s || true

# Ejecutar un primer respaldo inmediato para cumplir con el requisito de admisibilidad:
echo ">> Ejecutando respaldo inicial verificado..."
velero backup create sa-initial-backup \
  --include-namespaces produccion \
  --default-volumes-to-fs-backup \
  --wait

echo ""
echo "=== RESUMEN DE RESPALDOS CON VELERO ==="
velero backup get
echo ""
velero schedule get
echo ">> Velero configurado exitosamente!"
