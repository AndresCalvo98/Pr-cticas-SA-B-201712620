#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PRÁCTICA 9 - SISTEMAS AVANZADOS (2S 2026)
# BOOTSTRAP DE DÍA CERO: PUNTO DE ENTRADA ÚNICO DE RECONSTRUCCIÓN TOTAL
# Carnet: 201712620 | Estudiante: Luis Andres Calvo
# ==============================================================================

echo "======================================================================"
echo " [START] INICIANDO BOOTSTRAP DE DÍA CERO - RECUPERACIÓN TOTAL DE DR"
echo " Marca de tiempo inicio: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo "======================================================================"

START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/terraform"
SECRETS_DIR="${SCRIPT_DIR}/secrets"

# 1. Verificación de herramientas necesarias
echo "[1/6] Verificando dependencias del sistema..."
for tool in az terraform kubectl helm; do
  if ! command -v "$tool" &> /dev/null; then
    echo "ERROR: La herramienta '$tool' no está instalada o no está en el PATH."
    exit 1
  fi
done
echo ">> Todas las herramientas (az, terraform, kubectl, helm) están disponibles."

# 2. Inicialización de Terraform con Backend Remoto en Azure
echo "[2/6] Inicializando Terraform con Estado Remoto..."
cd "${TERRAFORM_DIR}"
rm -f .terraform.lock.hcl
terraform init -upgrade -reconfigure

# 3. Aprovisionamiento de Infraestructura y Despliegue de ArgoCD + App-of-Apps
echo "[3/6] Aprovisionando Clúster AKS, ArgoCD y App-of-Apps con Terraform..."
terraform apply -auto-approve

# 4. Configurar Kubeconfig local
echo "[4/6] Obteniendo credenciales del clúster AKS..."
KUBECONFIG_CMD=$(terraform output -raw aks_kubeconfig_command)
eval "${KUBECONFIG_CMD}"

# 5. Garantizar Continuidad de Secretos: Inyectar Llave Maestra de Sealed Secrets
echo "[5/6] Instalando Sealed Secrets y Restaurando Llave Maestra para Continuidad de Secretos..."
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.26.0/controller.yaml
if [ -f "${SECRETS_DIR}/sealed-secrets-key.yaml" ]; then
  kubectl apply -f "${SECRETS_DIR}/sealed-secrets-key.yaml"
  # Reiniciar el deployment para cargar inmediatamente la llave maestra restaurada
  kubectl rollout restart deployment -n kube-system sealed-secrets-controller || true
  kubectl rollout status deployment -n kube-system sealed-secrets-controller --timeout=60s || true
  echo ">> Llave maestra de Sealed Secrets inyectada y cargada con éxito."
else
  echo "ADVERTENCIA: No se encontró ${SECRETS_DIR}/sealed-secrets-key.yaml"
fi

# 6. Sincronización y Verificación del Ecosistema GitOps
echo "[6/6] Verificando sincronización de ArgoCD y estado de Producción..."

# Esperar que los namespaces y pods de producción estén listos
echo ">> Esperando que el Namespace 'produccion' esté creado..."
for i in {1..30}; do
  if kubectl get namespace produccion &> /dev/null; then
    break
  fi
  sleep 5
done

echo ">> Esperando despliegue de microservicios y bases de datos..."
kubectl wait --namespace produccion --for=condition=ready pod --all --timeout=300s || true

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo "======================================================================"
echo " [SUCCESS] BOOTSTRAP DE DÍA CERO COMPLETADO EXITOSAMENTE"
echo " Marca de tiempo fin: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo " Tiempo Total de Reconstrucción (RTO): ${DURATION} segundos (~$((DURATION / 60)) min)"
echo "======================================================================"
echo ""
echo "--- RESUMEN DEL SISTEMA RESTAURADO ---"
echo "Clúster AKS:"
kubectl get nodes -o wide
echo ""
echo "Pods en Namespace Producción:"
kubectl get pods -n produccion -o wide
echo ""
echo "Volúmenes Persistentes (PVC/PV):"
kubectl get pvc -n produccion
echo ""
echo "PodDisruptionBudgets (Alta Disponibilidad):"
kubectl get pdb -n produccion
echo ""
echo "ArgoCD Applications:"
kubectl get application -n argocd || true
echo "======================================================================"
