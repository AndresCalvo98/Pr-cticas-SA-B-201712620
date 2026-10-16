# 📖 Runbook de Recuperación ante Desastres (Disaster Recovery Runbook)

**Ecosistema:** Plataforma de Microservicios en Kubernetes (AKS)  
**Universidad San Carlos de Guatemala — Facultad de Ingeniería**  
**Sistemas Avanzados — Semestre 2S 2026**  
**Carnet:** 201712620 | **Estudiante:** Luis Andres Calvo  

---

## 🎯 Objetivo y Alcance

Este documento describe de manera exhaustiva el procedimiento estándar de operación (SOP) para reconstruir el ecosistema completo desde cero o recuperarlo ante una degradación severa (pérdida de nodos o corrupción de base de datos). 

**Este runbook está diseñado para que cualquier ingeniero o tercero pueda ejecutar la recuperación sin requerir contacto con el autor del sistema.**

---

## 📋 Requisitos Previos en la Máquina del Operador

Antes de iniciar la recuperación, asegúrese de contar con:
1. **Azure CLI (`az`)** versión 2.50+ instalada y autenticada.
2. **Terraform** versión 1.5.0+ instalada.
3. **Kubectl** versión 1.28+ instalada.
4. **Helm 3** versión 3.12+ instalada.
5. Permisos de `Contributor` en la suscripción de Azure.

---

## 🚨 PROCEDIMIENTO 1: Reconstrucción Total de Día Cero (Disaster Recovery Completo)

*Use este procedimiento ante la pérdida o destrucción total del clúster AKS.*

### Paso 1: Autenticación en Azure y Preparación del Entorno
```bash
# 1. Iniciar sesión en Azure
az login

# 2. Configurar la suscripción correcta (si aplica)
az account set --subscription "Azure subscription 1"

# 3. Clonar o acceder al repositorio del proyecto
cd P9
```

### Paso 2: Ejecución del Bootstrap Automatizado de Punto Único
Ejecute el script de bootstrap. **No requiere intervención manual durante su ejecución**:
```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

**Qué realiza este paso automáticamente:**
- Inicializa Terraform conectándose al backend remoto en Azure Blob Storage (`sasp9tfstate10854/tfstate`).
- Adquiere el bloqueo de estado (*lease lock*) para evitar colisiones.
- Aprovisiona el clúster AKS con 2 nodos trabajadores.
- Instala el servidor de ArgoCD con Helm.
- Instala el controlador de Sealed Secrets.
- Restaura la llave maestra RSA en `kube-system` para garantizar descifrado de secretos.
- Despliega la aplicación raíz (`sa-platform-root-app`) que sincroniza automáticamente todos los microservicios, PostgreSQL con volumen persistente y políticas de resiliencia.

### Paso 3: Verificación del Estado del Sistema Restaurado
Ejecute los siguientes comandos de comprobación:

1. **Verificar nodos del clúster (deben ser 2 en estado `Ready`):**
   ```bash
   kubectl get nodes
   ```
2. **Verificar que todos los pods de producción estén en ejecución (`Running`):**
   ```bash
   kubectl get pods -n produccion -o wide
   ```
3. **Verificar volumen persistente de la base de datos (`Bound`):**
   ```bash
   kubectl get pvc -n produccion
   ```
4. **Verificar sincronización de la aplicación raíz en ArgoCD (`Synced` / `Healthy`):**
   ```bash
   kubectl get application -n argocd
   ```

---

## 🛡️ PROCEDIMIENTO 2: Respuesta ante Falla de Nodo (Node Loss / Drain)

*Use este procedimiento cuando un nodo físico/virtual falle o requiera mantenimiento.*

### Paso 1: Drenar el nodo afectado
```bash
# Identificar nodos
kubectl get nodes

# Drenar el nodo objetivo (reemplazar <NODE_NAME>)
kubectl drain <NODE_NAME> --ignore-daemonsets --delete-emptydir-data --force
```

### Paso 2: Verificación de Continuidad del Servicio
1. **Comprobar que el PodDisruptionBudget protegió la disponibilidad:**
   ```bash
   kubectl get pdb -n produccion
   ```
   *Debe mostrar `MIN AVAILABLE: 1` y `ALLOWED DISRUPTIONS: 0` o `1`.*
2. **Comprobar que los pods se reubicaron en el nodo superviviente:**
   ```bash
   kubectl get pods -n produccion -o wide
   ```
3. **Comprobar que las peticiones al API Gateway responden HTTP 200 OK.**

### Paso 3: Reintegrar el nodo tras mantenimiento
```bash
kubectl uncordon <NODE_NAME>
```

---

## 💾 PROCEDIMIENTO 3: Restauración de Base de Datos con Velero (Data Recovery)

*Use este procedimiento ante corrupción lógica o borrado accidental de datos en PostgreSQL.*

### Paso 1: Identificar el último respaldo válido
```bash
velero backup get
```

### Paso 2: Ejecutar la restauración de datos
```bash
# Reemplazar <BACKUP_NAME> con el nombre del respaldo a restaurar
velero restore create restore-db-$(date +%s) --from-backup <BACKUP_NAME> --wait
```

### Paso 3: Verificar estado de la restauración
```bash
velero restore describe restore-db-$(date +%s)
```
*Debe indicar `Phase: Completed` con `Errors: 0`.*

### Paso 4: Validar integridad del contenido en la base de datos
```bash
PG_POD=$(kubectl get pod -n produccion -l app=sa-platform-postgresql -o jsonpath='{.items[0].metadata.name}' || kubectl get pod -n produccion -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')

kubectl exec -n produccion "$PG_POD" -- env PGPASSWORD="secretpassword" psql -U postgres -d transacciones -c "SELECT COUNT(*) FROM clientes_transacciones;"
```
*Debe retornar el total de registros respaldados.*

---

## 🔑 PROCEDIMIENTO 4: Recuperación de Llaves de Secretos (Sealed Secrets)

Si en una instalación independiente no se cargó la llave maestra:
```bash
# Aplicar el secreto maestro en kube-system
kubectl apply -f P9/secrets/sealed-secrets-key.yaml

# Reiniciar el controlador para que lea la llave
kubectl rollout restart deployment -n kube-system sealed-secrets
kubectl rollout status deployment -n kube-system sealed-secrets

# Forzar resincronización en ArgoCD para descifrar de nuevo
kubectl delete secret sa-platform-secrets -n produccion || true
```
*El controlador de Sealed Secrets detectará el SealedSecret en Git y regenerará el Secret desencriptado en segundos.*
