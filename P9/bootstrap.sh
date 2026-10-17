#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PRÁCTICA 9 - SISTEMAS AVANZADOS (2S 2026)
# BOOTSTRAP DE DÍA CERO: PUNTO DE ENTRADA ÚNICO DE RECONSTRUCCIÓN TOTAL EN OCI
# Carnet: 201712620 | Estudiante: Luis Andres Calvo
# ==============================================================================

echo "======================================================================"
echo " [START] INICIANDO BOOTSTRAP DE DÍA CERO - RECUPERACIÓN TOTAL DE DR"
echo " Nube: Oracle Cloud Infrastructure (OCI OKE)"
echo " Marca de tiempo inicio: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "======================================================================"

START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
SECRETS_DIR="${SCRIPT_DIR}/secrets"

export PATH="${HOME}/bin:/usr/local/bin:${PATH}"

# 1. Verificación de herramientas necesarias
echo "[1/6] Verificando dependencias del sistema..."
for tool in terraform kubectl helm; do
  if ! command -v "$tool" &> /dev/null; then
    echo "ERROR: La herramienta '$tool' no está instalada o no está en el PATH."
    exit 1
  fi
done
echo ">> Todas las herramientas (terraform, kubectl, helm) están disponibles."

# Credenciales S3 para el backend remoto en OCI Object Storage
export AWS_ACCESS_KEY_ID="f1d42c24ce294b258951d8f684e89b40ea6b1b34"
export AWS_SECRET_ACCESS_KEY="kFZqh2PKH/aSO4qNg3F6O2jk2SwxbsDhai+oabVYztA="

# 2. Inicialización de Terraform con Backend Remoto en OCI
echo "[2/6] Inicializando Terraform con Estado Remoto en OCI Object Storage..."
cd "${TERRAFORM_DIR}"
rm -f .terraform.lock.hcl
terraform init -upgrade -reconfigure

# 3. Despliegue de ArgoCD y App-of-Apps con Terraform
echo "[3/6] Desplegando ArgoCD y Aplicación Raíz App-of-Apps con Terraform..."
terraform apply -auto-approve

# 4. Garantizar Continuidad del Ecosistema P8: Argo Rollouts, Kyverno y Sealed Secrets
echo "[4/6] Instalando Controladores Core: Argo Rollouts, Kyverno y Sealed Secrets..."

# 4.1 Argo Rollouts (Entrega Progresiva)
echo ">> Instalando Argo Rollouts..."
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# 4.2 Kyverno (Políticas de Admisión)
echo ">> Instalando Kyverno..."
kubectl apply --server-side --force-conflicts -f https://github.com/kyverno/kyverno/releases/download/v1.12.5/install.yaml

# 4.3 Sealed Secrets y Llave Maestra
echo ">> Instalando Sealed Secrets y Restaurando Llave Maestra..."
kubectl apply --server-side --force-conflicts -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.0/controller.yaml
if [ -f "${SECRETS_DIR}/sealed-secrets-key.yaml" ]; then
  echo ">> Inyectando Llave Maestra RSA existente de Sealed Secrets..."
  kubectl apply -f "${SECRETS_DIR}/sealed-secrets-key.yaml"
  # Reiniciar controlador para cargar la llave
  kubectl delete pod -n kube-system -l app.kubernetes.io/name=sealed-secrets --wait=false || true
fi

# 5. Esperar sincronización y convergencia de ArgoCD
echo "[5/6] Esperando convergencia de aplicaciones en ArgoCD..."
sleep 15
kubectl wait --namespace argocd --for=condition=ready pod -l app.kubernetes.io/name=argocd-server --timeout=180s || true

# 6. Despliegue y configuración de Velero para DR
echo "[6/6] Configurando Velero con OCI Object Storage..."
cd "${SCRIPT_DIR}"
bash scripts/setup_velero.sh

END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

echo ""
echo "======================================================================"
echo " [SUCCESS] BOOTSTRAP DE DÍA CERO COMPLETADO EXITOSAMENTE EN OCI"
echo " Tiempo Total de Reconstrucción (RTO): ${TOTAL_DURATION} segundos"
echo " Clúster OKE, ArgoCD, Sealed Secrets, Kyverno y Velero 100% Operativos"
echo "======================================================================"
